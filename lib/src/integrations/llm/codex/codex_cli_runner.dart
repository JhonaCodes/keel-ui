import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger_rs/logger_rs.dart';

import 'package:keel_ui/src/core/services/cli_turn_workspace.dart';
import 'package:keel_ui/src/integrations/llm/llm.dart';
import 'package:keel_ui/src/integrations/llm/codex/codex_arguments.dart';
import 'package:keel_ui/src/integrations/llm/codex/codex_stream_reader.dart';

/// Corre un turno contra el binario `codex`. Migración literal de la rama
/// `isCodex=true` de `task_runner_isolate.dart` — mismo armado de
/// argumentos, mismo parseo de `--json`, mismo manejo de proceso.
class CodexCliRunner implements LlmRunner {
  const CodexCliRunner();

  @override
  Stream<LlmEvent> run(
    LlmTurnSpec spec, {
    required String userPath,
    required Stream<void> cancel,
    void Function(int pid)? onPidKnown,
  }) async* {
    // Archivos, nunca inline: un argumento de línea de comandos es legible
    // con `ps` — misma regla que CodexCliService. El temporal 0700 muere con
    // el turno.
    final workspace = await CliTurnWorkspace.create(
      mcpConfig: spec.mcpConfig,
      codexHooksConfig: spec.hooksConfig,
      hookFiles: spec.hookFiles,
    );

    final prompt = buildCodexPrompt(
      prompt: spec.prompt,
      sessionId: spec.sessionId,
      additionalSystemPrompt: spec.additionalSystemPrompt,
    );
    final arguments = buildCodexArguments(
      prompt: prompt,
      sessionId: spec.sessionId,
      model: spec.model,
      fullFileSystemAccess: spec.fullFileSystemAccess,
      codexProfileName: workspace.codexProfileName,
    );

    Process process;
    try {
      process = await Process.start(
        'codex',
        arguments,
        workingDirectory: spec.workingDirectory,
        // El PATH va explícito porque el heredado es el de `launchd`, no el
        // de la terminal.
        environment: {'PATH': userPath},
        runInShell: true,
      );
    } catch (error) {
      Log.e('Failed to start codex CLI', error: error);
      await workspace.dispose();
      yield {'type': 'failure', 'message': 'No se pudo iniciar codex: $error'};
      return;
    }
    onPidKnown?.call(process.pid);

    // codex lee stdin cuando no es un TTY y espera EOF — hay que cerrarlo.
    await process.stdin.close();

    var cancelled = false;
    final cancelSubscription = cancel.listen((_) {
      cancelled = true;
      process.kill();
    });

    final reader = CodexStreamReader();
    final stderrBuffer = StringBuffer();
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .forEach(stderrBuffer.write);
    final lines = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    try {
      await for (final line in lines) {
        if (cancelled) break;
        if (line.trim().isEmpty) continue;

        Map<String, dynamic> event;
        try {
          event = jsonDecode(line) as Map<String, dynamic>;
        } catch (_) {
          Log.w('Unparseable codex output line: $line');
          continue;
        }

        for (final message in reader.read(event)) {
          yield message;
        }
      }

      await stderrDone;
      if (!cancelled) {
        final exitCode = await process.exitCode;
        if (exitCode != 0) {
          final stderrText = stderrBuffer.toString().trim();
          yield {
            'type': 'failure',
            'message': stderrText.isEmpty
                ? 'codex terminó con código $exitCode'
                : stderrText,
          };
        }
      }
    } finally {
      await cancelSubscription.cancel();
      await workspace.dispose();
    }
  }
}
