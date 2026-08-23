library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:logger_rs/logger_rs.dart';

// The one thing this library does not re-declare: the permission list. Two
// copies of "what an agent is allowed to touch" drifting apart is exactly the
// kind of divergence that must not happen silently.
import 'package:keel_ui/src/core/services/claude_stream_events.dart';
import 'package:keel_ui/src/core/services/cli_turn_workspace.dart';
import 'package:keel_ui/src/core/services/cli_turn_contract.dart';
// El PATH del usuario se resuelve del lado del isolate principal y viaja
// en el bootstrap: leerlo cuesta abrir un shell de login, y el isolate
// del turno es nuevo en cada corrida.
import 'package:keel_ui/src/core/services/user_shell_path.dart';
// Same reason: which model names belong to which CLI is decided in ONE
// place, so a project turn cannot hand codex a Claude alias the 1:1 path
// already knows to withhold.
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart'
    show codexModelArgument;

part 'src/task_event.dart';
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
}
