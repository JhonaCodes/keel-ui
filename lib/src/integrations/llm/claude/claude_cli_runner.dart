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
import 'package:keel_ui/src/integrations/system_prompt/system_prompt.dart';
import 'package:keel_ui/src/integrations/llm/claude/claude_arguments.dart';
import 'package:keel_ui/src/integrations/llm/src/cli_cancel_guard.dart';
import 'package:keel_ui/src/integrations/llm/src/cli_turn_stream.dart';

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
    // Lo primero, antes de cualquier `await`: ver CliCancelGuard — un
    // cancel que llegue mientras se arma el workspace o se levanta el
    // proceso no se puede perder.
    final cancelGuard = CliCancelGuard(cancel);

    CliTurnWorkspace? workspace;
    try {
      final allowedTools = [...kAlwaysAllowedTools, ...spec.extraAllowedTools];
      final additionalPrompt = spec.additionalSystemPrompt;
      final systemPrompt =
          (additionalPrompt == null || additionalPrompt.isEmpty)
          ? kCliSystemHints
          : '$kCliSystemHints\n\n$additionalPrompt';

      // Archivos, nunca inline: un argumento de línea de comandos es
      // legible con `ps` — misma regla que ClaudeCliService. El temporal
      // 0700 muere con el turno.
      workspace = await CliTurnWorkspace.create(
        mcpConfig: spec.mcpConfig,
        claudeSettings: spec.hooksSettings,
        hookFiles: spec.hookFiles,
      );

      if (cancelGuard.cancelled) return;

      final arguments = buildClaudeArguments(
        prompt: spec.prompt,
        model: spec.model,
        effort: spec.effort,
        allowedTools: allowedTools,
        systemPrompt: systemPrompt,
        mcpConfigPath: workspace.mcpConfigPath,
        claudeSettingsPath: workspace.claudeSettingsPath,
        fullFileSystemAccess: spec.fullFileSystemAccess,
        planMode: spec.planMode,
        maxTurns: spec.maxTurns,
        maxBudgetUsd: spec.maxBudgetUsd,
        sessionId: spec.sessionId,
      );

      Process process;
      try {
        process = await Process.start(
          'claude',
          arguments,
          workingDirectory: spec.workingDirectory,
          // El PATH va explícito porque el heredado es el de `launchd`, no
          // el de la terminal. Y el plazo de tools MCP también: uno de los
          // nuestros espera a que la persona apruebe un cambio bloqueado, y
          // con el default del CLI eso se cae solo — ver
          // [kMcpToolTimeoutMillis].
          environment: {
            'PATH': userPath,
            'MCP_TOOL_TIMEOUT': '$kMcpToolTimeoutMillis',
          },
          runInShell: true,
        );
      } catch (error) {
        Log.e('Failed to start claude CLI', error: error);
        yield {
          'type': 'failure',
          'message': 'No se pudo iniciar claude: $error',
        };
        return;
      }
      cancelGuard.attach(process);
      onPidKnown?.call(process.pid);
      // `claude -p` con un stdin que no es TTY espera unos segundos por si
      // le llega el prompt por ahí, y al vencer escribe «Warning: no stdin
      // data received…» en stderr. El prompt ya va por argumento: cerrar el
      // stdin le ahorra la espera a CADA turno y saca ese aviso del stderr,
      // que es lo que se muestra como error cuando el turno sale con código
      // distinto de cero (por ejemplo, al tope de turnos).
      await process.stdin.close();

      // Uno por corrida: se acuerda de los `Task` que abrió este turno, que
      // es cómo reconoce después cuál `tool_result` es la devolución de un
      // subagente.
      final claudeReader = ClaudeStreamReader();
      yield* cliTurnEvents(
        lines: process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter()),
        read: claudeReader.read,
        stderr: process.stderr.transform(utf8.decoder).join(),
        exitCode: process.exitCode,
        provider: 'claude',
        isCancelled: () => cancelGuard.cancelled,
      );
    } finally {
      await cancelGuard.dispose();
      await workspace?.dispose();
    }
  }
}
