import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger_rs/logger_rs.dart';

// keel-debt: ClaudeStreamReader sigue en core/services porque session_map.dart
// también lo importa; mover el archivo a llm/claude/ es un cambio aparte que
// no aporta nada a este objetivo (reemplazar el isCodex del task runner).
import 'package:keel_ui/src/core/services/claude_stream_events.dart';
import 'package:keel_ui/src/core/services/cli_turn_contract.dart';
import 'package:keel_ui/src/core/services/cli_turn_workspace.dart';
import 'package:keel_ui/src/integrations/llm/llm.dart';
import 'package:keel_ui/src/integrations/llm/claude/claude_arguments.dart';

/// Corre un turno contra el binario `claude`. Migración literal de la rama
/// `isCodex=false` de `task_runner_isolate.dart` — mismo armado de
/// argumentos, mismo parseo de `stream-json`, mismo manejo de proceso.
class ClaudeCliRunner implements LlmRunner {
  const ClaudeCliRunner();

  @override
  Stream<LlmEvent> run(
    LlmTurnSpec spec, {
    required String userPath,
    required Stream<void> cancel,
    void Function(int pid)? onPidKnown,
  }) async* {
    final allowedTools = [...kAlwaysAllowedTools, ...spec.extraAllowedTools];
    final additionalPrompt = spec.additionalSystemPrompt;
    final systemPrompt = (additionalPrompt == null || additionalPrompt.isEmpty)
        ? kCliSystemHints
        : '$kCliSystemHints\n\n$additionalPrompt';

    // Archivos, nunca inline: un argumento de línea de comandos es legible
    // con `ps` — misma regla que ClaudeCliService. El temporal 0700 muere
    // con el turno.
    final workspace = await CliTurnWorkspace.create(
      mcpConfig: spec.mcpConfig,
      claudeSettings: spec.hooksSettings,
      hookFiles: spec.hookFiles,
    );

    final arguments = buildClaudeArguments(
      prompt: spec.prompt,
      model: spec.model,
      effort: spec.effort,
      allowedTools: allowedTools,
      systemPrompt: systemPrompt,
      mcpConfigPath: workspace.mcpConfigPath,
      claudeSettingsPath: workspace.claudeSettingsPath,
      fullFileSystemAccess: spec.fullFileSystemAccess,
      sessionId: spec.sessionId,
    );

    Process process;
    try {
      process = await Process.start(
        'claude',
        arguments,
        workingDirectory: spec.workingDirectory,
        // El PATH va explícito porque el heredado es el de `launchd`, no el
        // de la terminal.
        environment: {'PATH': userPath},
        runInShell: true,
      );
    } catch (error) {
      Log.e('Failed to start claude CLI', error: error);
      await workspace.dispose();
      yield {
        'type': 'failure',
        'message': 'No se pudo iniciar claude: $error',
      };
      return;
    }
    onPidKnown?.call(process.pid);

    var cancelled = false;
    final cancelSubscription = cancel.listen((_) {
      cancelled = true;
      process.kill();
    });

    // Uno por corrida: se acuerda de los `Task` que abrió este turno, que es
    // cómo reconoce después cuál `tool_result` es la devolución de un
    // subagente.
    final claudeReader = ClaudeStreamReader();
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
          Log.w('Unparseable claude output line: $line');
          continue;
        }

        for (final message in claudeReader.read(event)) {
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
                ? 'claude terminó con código $exitCode'
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
