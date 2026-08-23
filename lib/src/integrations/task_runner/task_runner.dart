library;

import 'dart:async';
import 'dart:isolate';

import 'package:logger_rs/logger_rs.dart';

// El isolate no arma argumentos de CLI ni parsea stdout: eso vive detrás del
// LlmRunner que le toque al proveedor — ver arquitectura-llm-providers.
import 'package:keel_ui/src/integrations/llm/llm.dart';
import 'package:keel_ui/src/integrations/llm/src/llm_dispatcher.dart';
// El PATH del usuario se resuelve del lado del isolate principal y viaja
// en el bootstrap: leerlo cuesta abrir un shell de login, y el isolate
// del turno es nuevo en cada corrida.
import 'package:keel_ui/src/core/services/user_shell_path.dart';

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
