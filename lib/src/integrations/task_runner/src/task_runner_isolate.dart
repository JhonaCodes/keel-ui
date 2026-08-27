part of '../task_runner.dart';

/// Bundles the two things `Isolate.spawn` can hand its entry point in one
/// message: where to reply, and the turn to run.
class _IsolateBootstrap {
  final SendPort mainSendPort;
  final Map<String, dynamic> specMessage;

  /// El PATH del usuario, ya resuelto por el isolate principal. Sin esto el
  /// CLI se busca en el PATH mínimo que `launchd` le da a una app abierta
  /// desde el Finder, donde `claude` no está.
  final String userPath;

  const _IsolateBootstrap(this.mainSendPort, this.specMessage, this.userPath);
}

/// Runs entirely inside the worker isolate. The [LlmRunner] owns the CLI
/// `Process` end to end — a live process can't cross an isolate boundary
/// either way — so cancellation reaches in via a command message turned into
/// a broadcast [Stream], not a handle held by the caller.
void _taskRunnerEntryPoint(_IsolateBootstrap bootstrap) {
  final commandPort = ReceivePort();
  bootstrap.mainSendPort.send(commandPort.sendPort);

  final spec = TaskRunSpec.fromMessage(bootstrap.specMessage);
  // Broadcast porque quien cancela (el listener de abajo) y quien escucha
  // (el runner, dentro de `_runInIsolate`) son suscriptores distintos del
  // mismo evento — un StreamController normal solo admite uno.
  final cancelController = StreamController<void>.broadcast();

  commandPort.listen((message) {
    if (message is Map && message['type'] == 'cancel') {
      cancelController.add(null);
    }
  });

  unawaited(
    _runInIsolate(
      spec: spec,
      userPath: bootstrap.userPath,
      mainSendPort: bootstrap.mainSendPort,
      commandPort: commandPort,
      cancel: cancelController.stream,
    ),
  );
}

Future<void> _runInIsolate({
  required TaskRunSpec spec,
  required String userPath,
  required SendPort mainSendPort,
  required ReceivePort commandPort,
  required Stream<void> cancel,
}) async {
  // El único lugar donde el alias persistido decide qué modelo corre —
  // agregar un proveedor nuevo sin extender `LlmProvider.fromLegacyAlias` ni
  // `dispatchLlmProvider` no compila. Ver arquitectura-llm-providers.
  final provider = LlmProvider.fromLegacyAlias(spec.provider);
  final turnSpec = LlmTurnSpec(
    prompt: spec.prompt,
    workingDirectory: spec.workingDirectory,
    model: spec.model,
    fullFileSystemAccess: spec.fullFileSystemAccess,
    effort: spec.effort,
    extraAllowedTools: spec.extraAllowedTools,
    sessionId: spec.sessionId,
    additionalSystemPrompt: spec.additionalSystemPrompt,
    mcpConfig: spec.mcpConfig,
    hooksSettings: spec.hooksSettings,
    hooksConfig: spec.hooksConfig,
    hookFiles: spec.hookFiles,
    conversationHistory: spec.conversationHistory,
    planMode: spec.planMode,
    maxTurns: spec.maxTurns,
  );

  final events =
      dispatchLlmProvider(provider, providerApiKey: spec.providerApiKey).run(
        turnSpec,
        userPath: userPath,
        cancel: cancel,
        onPidKnown: (pid) {
          // El pid cruza el isolate como dato: un Process no se puede mandar, y
          // del otro lado solo hace falta el número para poder mirarlo con `ps`
          // y decir de parte de quién corre.
          mainSendPort.send({'type': 'processStarted', 'pid': pid});
        },
      );

  await for (final event in events) {
    mainSendPort.send(event);
  }

  mainSendPort.send({'type': 'done'});
  commandPort.close();
}
