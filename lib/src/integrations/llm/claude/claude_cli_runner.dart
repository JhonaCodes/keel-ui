import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger_rs/logger_rs.dart';

// keel-debt: ClaudeStreamReader sigue en core/services porque session_map.dart
// también lo importa; mover el archivo a llm/claude/ es un cambio aparte que
// no aporta nada a este objetivo (reemplazar el isCodex del task runner).
import 'package:keel_ui/src/core/services/claude_stream_events.dart';
import 'package:keel_ui/src/core/services/cli_turn_workspace.dart';
import 'package:keel_ui/src/integrations/llm/llm.dart';
import 'package:keel_ui/src/integrations/llm/claude/claude_arguments.dart';
import 'package:keel_ui/src/integrations/llm/claude/claude_launch.dart';
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
    Stream<String> steer = const Stream<String>.empty(),
    void Function(int pid)? onPidKnown,
  }) async* {
    // Lo primero, antes de cualquier `await`: ver CliCancelGuard — un
    // cancel que llegue mientras se arma el workspace o se levanta el
    // proceso no se puede perder.
    final cancelGuard = CliCancelGuard(cancel);

    CliTurnWorkspace? workspace;
    try {
      final launch = await ClaudeLaunch.prepare(spec);
      workspace = launch.workspace;

      if (cancelGuard.cancelled) return;

      final arguments = buildClaudeArguments(
        model: spec.model,
        effort: spec.effort,
        allowedTools: launch.allowedTools,
        systemPrompt: launch.systemPrompt,
        mcpConfigPath: launch.workspace.mcpConfigPath,
        claudeSettingsPath: launch.workspace.claudeSettingsPath,
        fullFileSystemAccess: spec.fullFileSystemAccess,
        planMode: spec.planMode,
        maxTurns: spec.maxTurns,
        maxBudgetUsd: spec.maxBudgetUsd,
        sessionId: spec.sessionId,
      );

      Process process;
      try {
        process = await ClaudeLaunch.start(
          arguments,
          workingDirectory: spec.workingDirectory,
          userPath: userPath,
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
      // Escribir en un proceso que ya murió falla acá, no en la llamada.
      unawaited(
        process.stdin.done.catchError(
          (Object error) => Log.w('stdin de claude cerrado: $error'),
        ),
      );

      // El prompt es la primera línea del stdin, y el stdin queda abierto
      // mientras el modelo trabaja: es el canal por el que un mensaje del
      // usuario entra en el próximo corte del turno, sin matar el proceso.
      // Se cierra en el primer `result`; lo que ya se escribió, el CLI lo
      // atiende antes de salir (como turno siguiente si el modelo ya había
      // terminado), y con eso el proceso sale solo. Verificado contra el CLI
      // 2.1.280.
      var inputOpen = true;
      process.stdin.writeln(claudeUserLine(spec.prompt));
      void closeInput() {
        if (!inputOpen) return;
        inputOpen = false;
        unawaited(process.stdin.close());
      }

      // Uno por corrida: se acuerda de los `Task` que abrió este turno, que
      // es cómo reconoce después cuál `tool_result` es la devolución de un
      // subagente.
      final claudeReader = ClaudeStreamReader();
      final turn = cliTurnEvents(
        lines: process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter()),
        read: (event) {
          if (event['type'] == 'result') closeInput();
          return claudeReader.read(event);
        },
        stderr: process.stderr.transform(utf8.decoder).join(),
        exitCode: process.exitCode,
        provider: 'claude',
        isCancelled: () => cancelGuard.cancelled,
      );

      // Los eventos del turno y los acuses de los mensajes salen por el mismo
      // stream. Un mensaje que llega con el stdin ya cerrado no tiene acuse:
      // quien lo mandó lo devuelve a la cola.
      final output = StreamController<LlmEvent>();
      final steering = steer.listen((text) {
        if (!inputOpen) return;
        process.stdin.writeln(claudeUserLine(text, priority: 'next'));
        output.add({'type': 'steerDelivered', 'text': text});
      });
      final forwarding = turn.listen(
        output.add,
        onError: output.addError,
        onDone: () {
          unawaited(steering.cancel());
          unawaited(output.close());
        },
      );
      try {
        yield* output.stream;
      } finally {
        await steering.cancel();
        await forwarding.cancel();
        closeInput();
      }
    } finally {
      await cancelGuard.dispose();
      await workspace?.dispose();
    }
  }
}
