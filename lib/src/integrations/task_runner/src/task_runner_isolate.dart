part of '../task_runner.dart';

const _diagramSystemPromptHint =
    'When you need to show a diagram, hierarchy, timeline, or flowchart, '
    'prefer a ```mermaid fenced code block over generating raw SVG — it is '
    'far cheaper in tokens and renders just as well in this chat client. '
    'Only fall back to raw ```svg when mermaid genuinely cannot express the '
    'shape you need (e.g. precise custom illustrations).';

const _codeEditSystemPromptHint =
    'When the user asks you to write, rewrite, convert, fix, or refactor '
    'code for a real file on disk — especially when they reference a '
    'specific file or line — actually make the change with your file tools '
    '(Write/Edit/MultiEdit) instead of only printing the new code in your '
    'reply. This client renders real file edits as an interactive '
    'diff/edit card the user can review, tweak, and save directly, which is '
    'far more useful to them than a code block in prose. Only print code '
    'inline when the user is explicitly asking to see/discuss a snippet, '
    'not asking for a change to be made.';

const _appendedSystemPrompt =
    '$_diagramSystemPromptHint\n\n$_codeEditSystemPromptHint';

/// Bundles the two things `Isolate.spawn` can hand its entry point in one
/// message: where to reply, and the turn to run.
class _IsolateBootstrap {
  final SendPort mainSendPort;
  final Map<String, dynamic> specMessage;
  const _IsolateBootstrap(this.mainSendPort, this.specMessage);
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
      mainSendPort: bootstrap.mainSendPort,
      commandPort: commandPort,
      isCancelled: () => cancelled,
      onProcessStarted: (started) => process = started,
    ),
  );
}

Future<void> _runInIsolate({
  required TaskRunSpec spec,
  required SendPort mainSendPort,
  required ReceivePort commandPort,
  required bool Function() isCancelled,
  required void Function(Process) onProcessStarted,
}) async {
  final allowedTools = [...kAlwaysAllowedTools, ...spec.extraAllowedTools];
  final additionalPrompt = spec.additionalSystemPrompt;
  final systemPrompt = (additionalPrompt == null || additionalPrompt.isEmpty)
      ? _appendedSystemPrompt
      : '$_appendedSystemPrompt\n\n$additionalPrompt';

  // File, never inline: the config may embed resolved secret values and an
  // inline argument is world-readable via `ps` — same rule as
  // ClaudeCliService. The 0700 temp dir dies with the turn.
  Directory? mcpConfigDir;
  String? mcpConfigPath;
  if (spec.mcpConfig != null) {
    mcpConfigDir = await Directory.systemTemp.createTemp('keel_mcpcfg_');
    final file = File('${mcpConfigDir.path}/mcp.json');
    await file.writeAsString(spec.mcpConfig!);
    mcpConfigPath = file.path;
  }

  Future<void> cleanUpMcpConfig() async {
    if (mcpConfigDir == null) return;
    try {
      await mcpConfigDir.delete(recursive: true);
    } catch (error) {
      Log.w('Could not clean up ${mcpConfigDir.path}: $error');
    }
  }

  final isCodex = spec.provider == 'codex';

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
      runInShell: true,
    );
  } catch (error) {
    Log.e('Failed to start $executable CLI', error: error);
    await cleanUpMcpConfig();
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
        : _parseEventToMessages(event);
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

  await cleanUpMcpConfig();
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
        {'type': 'turnCompleted', 'isError': false, 'costUsd': 0.0,
          'durationMs': 0},
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

/// Ports `ClaudeCliService._parseEvent`'s NDJSON parsing, emitting plain
/// message maps (isolate-sendable) instead of typed events.
List<Map<String, dynamic>> _parseEventToMessages(Map<String, dynamic> event) {
  final type = event['type'] as String?;
  switch (type) {
    case 'system':
      return switch (event['subtype']) {
        'init' => switch (event['session_id'] as String?) {
          null => const <Map<String, dynamic>>[],
          final sessionId => [
            {'type': 'sessionStarted', 'sessionId': sessionId},
          ],
        },
        'permission_denied' => [
          {
            'type': 'permissionDenied',
            'toolName': event['tool_name'] as String? ?? 'desconocido',
            'message': event['message'] as String? ?? 'Permiso denegado.',
          },
        ],
        _ => const <Map<String, dynamic>>[],
      };

    case 'assistant':
      final message = event['message'] as Map<String, dynamic>?;
      final content = message?['content'] as List<dynamic>?;
      if (content == null) return const [];

      final events = <Map<String, dynamic>>[];
      final textBuffer = StringBuffer();
      for (final block in content.whereType<Map<String, dynamic>>()) {
        switch (block['type']) {
          case 'thinking':
            final thinking = block['thinking'] as String?;
            if (thinking != null && thinking.isNotEmpty) {
              events.add({'type': 'reasoningChunk', 'text': thinking});
            }
          case 'text':
            textBuffer.write(block['text'] as String? ?? '');
          case 'tool_use':
            final name = block['name'] as String?;
            if (name != null) {
              events.add({
                'type': 'toolUse',
                'name': name,
                'input': block['input'] as Map<String, dynamic>?,
              });
            }
        }
      }
      final text = textBuffer.toString();
      if (text.isNotEmpty) events.add({'type': 'assistantText', 'text': text});
      return events;

    case 'result':
      final events = <Map<String, dynamic>>[
        {
          'type': 'turnCompleted',
          'isError': event['is_error'] as bool,
          'costUsd': (event['total_cost_usd'] as num?)?.toDouble() ?? 0,
          'durationMs': event['duration_ms'] as int? ?? 0,
        },
      ];

      final usage = event['usage'] as Map<String, dynamic>?;
      final modelUsage = event['modelUsage'] as Map<String, dynamic>?;
      final mainModel = _mainModelUsageEntry(modelUsage);
      final contextWindow = mainModel?['contextWindow'] as int?;
      if (usage != null && contextWindow != null) {
        final usedTokens =
            (usage['input_tokens'] as num? ?? 0).toInt() +
            (usage['cache_creation_input_tokens'] as num? ?? 0).toInt() +
            (usage['cache_read_input_tokens'] as num? ?? 0).toInt();
        events.add({
          'type': 'contextUsage',
          'usedTokens': usedTokens,
          'contextWindowTokens': contextWindow,
        });
      }
      return events;

    default:
      return const [];
  }
}

/// Picks the modelUsage entry with the largest total usage — that's the
/// model actually driving this turn, as opposed to small internal
/// side-calls (e.g. a background haiku call) that also appear in the map.
Map<String, dynamic>? _mainModelUsageEntry(Map<String, dynamic>? modelUsage) {
  if (modelUsage == null) return null;

  Map<String, dynamic>? best;
  var bestTotal = -1;
  for (final value in modelUsage.values) {
    final entry = value as Map<String, dynamic>;
    final total =
        (entry['inputTokens'] as num? ?? 0).toInt() +
        (entry['cacheReadInputTokens'] as num? ?? 0).toInt() +
        (entry['cacheCreationInputTokens'] as num? ?? 0).toInt();
    if (total > bestTotal) {
      bestTotal = total;
      best = entry;
    }
  }
  return best;
}
