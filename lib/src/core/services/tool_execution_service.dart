import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger_rs/logger_rs.dart';

import 'package:keel_ui/src/core/services/user_shell_path.dart';
import 'package:keel_ui/src/modules/tools/model/tool.dart';

/// stdout/stderr are truncated to this many characters each before going
/// back to the model — a runaway print loop must not flood the context.
const _maxCapturedOutputChars = 20000;

/// The outcome of one tool run, exactly as it gets reported to the model.
class ToolRunResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  final bool timedOut;

  const ToolRunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.timedOut,
  });

  bool get ok => !timedOut && exitCode == 0;

  Map<String, dynamic> toJson() => {
    'ok': ok,
    'exit_code': exitCode,
    'stdout': stdout,
    'stderr': stderr,
    'timed_out': timedOut,
  };
}

/// Runs a registered [Tool] as a one-shot process: the code is written to a
/// fresh temp file, executed under the tool's runtime with [args] as argv,
/// and killed if it outlives its timeout. Stateless — every run is
/// independent, which is the whole point of these tools being deterministic.
class ToolExecutionService {
  Future<ToolRunResult> run(
    Tool tool, {
    List<String> args = const [],
    required String workingDirectory,
    Map<String, String> environment = const {},
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('keel_tool_');
    try {
      final script = File(
        '${tempDir.path}/${tool.name}.${tool.runtime.fileExtension}',
      );
      await script.writeAsString(tool.code);

      // Ruta absoluta, no el nombre: sin `runInShell`, `Process.start` busca
      // el runtime en el PATH de la app —el mínimo de `launchd`— y no en el
      // del usuario, que es donde están `python3`, `node` y compañía.
      final executable = await UserShellPath.locate(tool.runtime.executable);
      if (executable == null) {
        return ToolRunResult(
          exitCode: -1,
          stdout: '',
          stderr:
              'No se encontró ${tool.runtime.executable} en el PATH. '
              '¿Está instalado en esta máquina?',
          timedOut: false,
        );
      }

      final Process process;
      try {
        process = await Process.start(
          executable,
          [script.path, ...args],
          workingDirectory: workingDirectory,
          // Declared secrets ride on TOP of the inherited environment —
          // Process.start merges when includeParentEnvironment stays true.
          // El PATH del usuario va debajo para que el script pueda invocar
          // otros binarios suyos; un secret que se llame PATH sigue ganando.
          environment: {
            ...await UserShellPath.environment(),
            ...environment,
          },
        );
      } catch (error) {
        Log.e('Failed to start tool "${tool.name}"', error: error);
        return ToolRunResult(
          exitCode: -1,
          stdout: '',
          stderr:
              'No se pudo iniciar ${tool.runtime.executable}: $error. '
              '¿Está instalado en esta máquina?',
          timedOut: false,
        );
      }

      final stdoutFuture = process.stdout.transform(utf8.decoder).join();
      final stderrFuture = process.stderr.transform(utf8.decoder).join();

      var timedOut = false;
      final timeout = Duration(
        seconds: tool.timeoutSeconds.clamp(1, kMaxToolTimeoutSeconds),
      );
      final timer = Timer(timeout, () {
        timedOut = true;
        process.kill(ProcessSignal.sigkill);
      });

      final exitCode = await process.exitCode;
      timer.cancel();

      return ToolRunResult(
        exitCode: exitCode,
        stdout: _truncate(await stdoutFuture),
        stderr: _truncate(await stderrFuture),
        timedOut: timedOut,
      );
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (error) {
        Log.w('Could not clean up ${tempDir.path}: $error');
      }
    }
  }

  String _truncate(String output) {
    if (output.length <= _maxCapturedOutputChars) return output;
    return '${output.substring(0, _maxCapturedOutputChars)}\n'
        '[…salida truncada: ${output.length} caracteres en total]';
  }
}
