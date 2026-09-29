library;

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:logger_rs/logger_rs.dart';

// El isolate no arma argumentos de CLI ni parsea stdout: eso vive detrás del
// LlmRunner que le toque al proveedor — ver arquitectura-llm-providers.
import 'package:keel_ui/src/integrations/llm/llm.dart';
import 'package:keel_ui/src/integrations/llm/src/llm_dispatcher.dart';
import 'package:keel_ui/src/integrations/machine/machine.dart';
// El PATH del usuario se resuelve del lado del isolate principal y viaja
// en el bootstrap: leerlo cuesta abrir un shell de login, y el isolate
// del turno es nuevo en cada corrida.
import 'package:keel_ui/src/core/services/user_shell_path.dart';

part 'src/task_event.dart';
part 'src/task_live_session.dart';
part 'src/task_run.dart';
part 'src/task_run_spec.dart';
part 'src/task_runner_isolate.dart';

/// Runs one CLI turn per call, each in its own isolate — keeps NDJSON
/// parsing and the multi-MB JSON work around file edits off the UI isolate.
/// The CLI process itself already runs outside the Dart process either way
/// (`Process.start`), so the isolate isn't what makes turns run
/// concurrently — it's there so parsing a turn's output, and the
/// [FileEdit]-sized payloads inside it, never blocks a frame.
///
/// The isolate owns the CLI [Process] end to end — a live [Process] handle
/// can't cross an isolate boundary — so [TaskRun.cancel] sends it a kill
/// command instead of reaching in from the outside.
class TaskRunner {
  const TaskRunner._();

  static Future<TaskRun> run(TaskRunSpec spec) => _startTaskRun(spec);

  static final Map<String, _LiveTaskSession> _live = {};

  /// Whether [spec]'s provider can serve several turns with one process.
  static bool supportsLive(TaskRunSpec spec) =>
      dispatchLlmLiveSession(LlmProvider.fromLegacyAlias(spec.provider)) !=
      null;

  /// Starts the process of conversation [key] ahead of its next message, so
  /// that message only waits for the model. A no-op when a matching process
  /// is already up, or when a turn is running on a different one.
  static Future<void> warmLive(
    String key,
    TaskRunSpec spec, {
    required String label,
    required void Function(TaskRun run) onSpontaneousTurn,
  }) async {
    final current = _live[key];
    if (current != null && current.isBusy) return;
    await _liveSessionFor(
      key,
      spec,
      label: label,
      onSpontaneousTurn: onSpontaneousTurn,
    );
  }

  /// Runs one turn of conversation [key] on its live process, starting one
  /// if there is none or if [spec] no longer matches the running one — the
  /// new process resumes the same provider session. [onSpontaneousTurn]
  /// receives the turns the provider opens on its own.
  static Future<TaskRun> runLive(
    String key,
    TaskRunSpec spec, {
    required String label,
    required void Function(TaskRun run) onSpontaneousTurn,
  }) async {
    final session = await _liveSessionFor(
      key,
      spec,
      label: label,
      onSpontaneousTurn: onSpontaneousTurn,
    );
    return session.startTurn(spec.prompt);
  }

  /// Lets conversation [key]'s process finish and exit.
  static void closeLive(String key) => _live.remove(key)?.close();

  static Future<_LiveTaskSession> _liveSessionFor(
    String key,
    TaskRunSpec spec, {
    required String label,
    required void Function(TaskRun run) onSpontaneousTurn,
  }) async {
    final spawnKey = spec.liveSpawnKey;
    final current = _live[key];
    if (current != null && current.serves(spawnKey, spec.sessionId)) {
      current
        ..label = label
        ..onSpontaneousTurn = onSpontaneousTurn;
      await current.started;
      return current;
    }
    current?.close();

    late final _LiveTaskSession session;
    session = _LiveTaskSession(
      spawnKey: spawnKey,
      spawnSessionId: spec.sessionId,
      label: label,
      onSpontaneousTurn: onSpontaneousTurn,
      onClosed: () {
        if (identical(_live[key], session)) _live.remove(key);
      },
    );
    _live[key] = session;
    await session.start(spec);
    return session;
  }
}
