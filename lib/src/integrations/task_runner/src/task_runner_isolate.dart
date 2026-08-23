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

  const _IsolateBootstrap(
    this.mainSendPort,
    this.specMessage,
    this.userPath,
  );
}

/// Runs entirely inside the worker isolate. Owns the CLI [Process] end to
/// end — a live [Process] can't cross an isolate boundary, so cancellation
/// has to reach in via a command message rather than a handle held by the
/// caller.
void _taskRunnerEntryPoint(_IsolateBootstrap bootstrap) {
  final commandPort = ReceivePort();
  bootstrap.mainSendPort.send(commandPort.sendPort);

  final spec = TaskRunSpec.fromMessage(bootstrap.specMessage);
  var cancelled = false;
  Process? process;

  commandPort.listen((message) {
    if (message is Map && message['type'] == 'cancel') {
      cancelled = true;
      process?.kill();
    }
  });

  unawaited(
    _runInIsolate(
      spec: spec,
      userPath: bootstrap.userPath,
      mainSendPort: bootstrap.mainSendPort,
      commandPort: commandPort,
      isCancelled: () => cancelled,
      onProcessStarted: (started) {
        process = started;
        // El pid cruza el isolate como dato: un Process no se puede mandar,
        // y del otro lado solo hace falta el número para poder mirarlo con
        // `ps` y decir de parte de quién corre.
        bootstrap.mainSendPort.send({
          'type': 'processStarted',
          'pid': started.pid,
        });
      },
    ),
  );
}

Future<void> _runInIsolate({
  required TaskRunSpec spec,
  required String userPath,
  required SendPort mainSendPort,
  required ReceivePort commandPort,
  required bool Function() isCancelled,
  required void Function(Process) onProcessStarted,
}) async {
  final allowedTools = [...kAlwaysAllowedTools, ...spec.extraAllowedTools];
  final additionalPrompt = spec.additionalSystemPrompt;
  final systemPrompt = (additionalPrompt == null || additionalPrompt.isEmpty)
      ? kCliSystemHints
      : '$kCliSystemHints\n\n$additionalPrompt';

  final isCodex = spec.provider == 'codex';

  // Archivos, nunca inline: llevan valores de secrets resueltos y un
  // argumento es legible con `ps` — misma regla que ClaudeCliService. El
  // temporal 0700 muere con el turno. Los hooks vienen YA renderizados en el
  // spec: acá no se alcanza el catálogo ni la bóveda de secrets.
  final workspace = await CliTurnWorkspace.create(
    mcpConfig: spec.mcpConfig,
    claudeSettings: isCodex ? null : spec.hooksSettings,
    codexHooksConfig: isCodex ? spec.hooksConfig : null,
    hookFiles: spec.hookFiles,
  );
  final mcpConfigPath = workspace.mcpConfigPath;

  // Codex has no system-prompt flag: on the FIRST turn of a session the
  // member's prompt stack rides as a delimited preamble of the user prompt
  // (resumed turns keep it from the thread history). Mirrors
  // CodexCliService — the isolate is self-contained by design.
  final codexPrompt =
      (spec.sessionId == null &&
          additionalPrompt != null &&
          additionalPrompt.isNotEmpty)
      ? '### Instrucciones de tu rol (fijas para toda la conversación)\n'
            '$additionalPrompt\n'
            '### Fin de instrucciones\n\n'
            '${spec.prompt}'
      : spec.prompt;

  // Same rule as CodexCliService: only a codex model reaches `-m`. A member
  // carrying a Claude alias (every codex agent created before the catalogs
  // were split per provider) falls back to the codex config's model.
  final codexModel = codexModelArgument(spec.model);

  final arguments = isCodex
      ? [
          'exec',
          if (spec.sessionId != null) ...['resume', spec.sessionId!],
          if (codexModel != null) ...['-m', codexModel],
          '--json',
          '--skip-git-repo-check',
          '-s',
          spec.fullFileSystemAccess ? 'danger-full-access' : 'workspace-write',
          if (workspace.codexProfileName != null) ...[
            '-p',
            workspace.codexProfileName!,
          ],
          '--color',
          'never',
          codexPrompt,
        ]
      : [
          '-p',
          spec.prompt,
          '--output-format',
          'stream-json',
          '--verbose',
          // Sin esto el texto y el pensamiento de un subagente llegan
          // mezclados con los del padre: el mapa no puede darle nodo propio a
          // algo que no sabe distinguir.
          '--forward-subagent-text',
          '--model',
          spec.model,
          '--effort',
          spec.effort,
          '--allowedTools',
          allowedTools.join(','),
          '--append-system-prompt',
          systemPrompt,
          if (mcpConfigPath != null) ...[
            '--mcp-config',
            mcpConfigPath,
            '--strict-mcp-config',
          ],
          if (workspace.claudeSettingsPath != null) ...[
            '--settings',
            workspace.claudeSettingsPath!,
          ],
          if (spec.fullFileSystemAccess) ...['--add-dir', '/'],
          if (spec.sessionId != null) ...['--resume', spec.sessionId!],
        ];

  final executable = isCodex ? 'codex' : 'claude';

  Process process;
  try {
    process = await Process.start(
      executable,
      arguments,
      workingDirectory: spec.workingDirectory,
      // El PATH va explícito porque el heredado es el de `launchd`, no el de
      // la terminal. `runInShell` sigue puesto: es el `sh` el que resuelve el
      // nombre, y lo resuelve contra ESTE PATH.
      environment: {'PATH': userPath},
      runInShell: true,
    );
  } catch (error) {
    Log.e('Failed to start $executable CLI', error: error);
    await workspace.dispose();
    mainSendPort.send({
      'type': 'failure',
      'message': 'No se pudo iniciar $executable: $error',
    });
    mainSendPort.send({'type': 'done'});
    commandPort.close();
    return;
  }
  onProcessStarted(process);

  // codex reads stdin when it isn't a TTY and waits for EOF — close it.
  if (isCodex) await process.stdin.close();

  // Uno por corrida: se acuerda de los `Task` que abrió este turno, que es
  // cómo reconoce después cuál `tool_result` es la devolución de un subagente.
  final claudeReader = ClaudeStreamReader();
  final stderrBuffer = StringBuffer();
  final stderrDone = process.stderr
      .transform(utf8.decoder)
      .forEach(stderrBuffer.write);

  final lines = process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter());

  await for (final line in lines) {
    if (isCancelled()) break;
    if (line.trim().isEmpty) continue;

    Map<String, dynamic> event;
    try {
      event = jsonDecode(line) as Map<String, dynamic>;
    } catch (_) {
      Log.w('Unparseable claude output line: $line');
      continue;
    }

    final messages = isCodex
        ? _parseCodexEventToMessages(event)
        : claudeReader.read(event);
    for (final messageMap in messages) {
      mainSendPort.send(messageMap);
    }
  }

  await stderrDone;
  if (!isCancelled()) {
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      final stderrText = stderrBuffer.toString().trim();
      mainSendPort.send({
        'type': 'failure',
        'message': stderrText.isEmpty
            ? 'claude terminó con código $exitCode'
            : stderrText,
      });
    }
  }

  await workspace.dispose();
  mainSendPort.send({'type': 'done'});
  commandPort.close();
}

/// Ports `CodexCliService._parseEvent`'s JSONL parsing (verified against
/// codex-cli 0.142.3: `thread.started` / `turn.*` / `item.*` events),
/// emitting the same plain message maps the claude dialect emits.
List<Map<String, dynamic>> _parseCodexEventToMessages(
  Map<String, dynamic> event,
) {
  switch (event['type'] as String?) {
    case 'thread.started':
      return switch (event['thread_id'] as String?) {
        null => const [],
        final threadId => [
          {'type': 'sessionStarted', 'sessionId': threadId},
        ],
      };

    case 'item.completed':
    case 'item.updated':
    case 'item.started':
      final item = event['item'] as Map<String, dynamic>?;
      if (item == null) return const [];
      final isCompleted = event['type'] == 'item.completed';

      switch (item['type'] as String?) {
        case 'agent_message':
          final text = item['text'] as String?;
          return (isCompleted && text != null && text.isNotEmpty)
              ? [
                  {'type': 'assistantText', 'text': text},
                ]
              : const [];
        case 'reasoning':
          final text = item['text'] as String?;
          return (isCompleted && text != null && text.isNotEmpty)
              ? [
                  {'type': 'reasoningChunk', 'text': text},
                ]
              : const [];
        case 'command_execution':
          final command = item['command'] as String?;
          return (!isCompleted && command != null)
              ? [
                  {
                    'type': 'toolUse',
                    'name': 'Bash',
                    'input': {'command': command},
                  },
                ]
              : const [];
        case 'file_change':
          return isCompleted
              ? const []
              : const [
                  {'type': 'toolUse', 'name': 'Edit', 'input': null},
                ];
        case 'mcp_tool_call':
          return isCompleted
              ? const []
              : [
                  {
                    'type': 'toolUse',
                    'name': event['item'] is Map
                        ? ((event['item'] as Map)['tool'] as String? ?? 'mcp')
                        : 'mcp',
                    'input': null,
                  },
                ];
        case 'web_search':
          return isCompleted
              ? const []
              : const [
                  {'type': 'toolUse', 'name': 'WebSearch', 'input': null},
                ];
        default:
          return const [];
      }

    case 'turn.completed':
      return const [
        {
          'type': 'turnCompleted',
          'isError': false,
          'costUsd': 0.0,
          'durationMs': 0,
        },
      ];

    case 'turn.failed':
      final message =
          (event['error'] as Map<String, dynamic>?)?['message'] as String?;
      return [
        if (message != null) {'type': 'failure', 'message': message},
        const {
          'type': 'turnCompleted',
          'isError': true,
          'costUsd': 0.0,
          'durationMs': 0,
        },
      ];

    case 'error':
      return switch (event['message'] as String?) {
        null => const [],
        final message => [
          {'type': 'failure', 'message': message},
        ],
      };

    default:
      return const [];
  }
}
