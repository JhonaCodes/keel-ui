/// Traduce el dialecto JSONL de `codex exec --json` a los mismos mensajes
/// planos que emite `ClaudeStreamReader` — el contrato normalizado que
/// `TaskEvent.fromMessage` ya sabe parsear. Sin estado propio hoy (a
/// diferencia de `ClaudeStreamReader`, que sí recuerda qué `Task` abrió
/// cada subagente); queda como clase para no cambiar la forma de la API si
/// codex necesita ese mismo seguimiento más adelante.
///
/// Portado literal de `CodexCliService._parseEvent` / el `_isCodex=true` de
/// `task_runner_isolate.dart` (verificado contra codex-cli 0.142.3:
/// eventos `thread.started` / `turn.*` / `item.*`).
class CodexStreamReader {
  List<Map<String, dynamic>> read(Map<String, dynamic> event) {
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
        final usage = (event['usage'] as Map?)?.cast<String, dynamic>();
        final cached = _usageInt(usage?['cached_input_tokens']);
        final cacheWrite = _usageInt(usage?['cache_write_input_tokens']);
        final reportedInput = _usageInt(usage?['input_tokens']);
        return [
          {
            'type': 'turnCompleted',
            'isError': false,
            'costUsd': 0.0,
            'costReported': false,
            'durationMs': 0,
            if (usage != null) ...{
              // Codex reports total input including the cached buckets. Keel's
              // normalized contract keeps the buckets disjoint so totals do
              // not count the same token twice.
              'inputTokens': (reportedInput - cached - cacheWrite).clamp(
                0,
                reportedInput,
              ),
              'outputTokens': _usageInt(usage['output_tokens']),
              'cacheReadTokens': cached,
              'cacheCreationTokens': cacheWrite,
              // `codex exec resume` reports the accumulated CLI-thread usage,
              // not the delta for only this request. The session model uses
              // this marker to subtract its persisted previous snapshot.
              'tokensReported': true,
              'usageIsCumulative': true,
            },
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
}

int _usageInt(Object? value) => (value as num?)?.toInt() ?? 0;
