/// Normalizes codex exec JSONL into the task runner event contract.
/// Collaboration item completion ends the tool call, not the child: child
/// lifecycle comes from agents_states and is deduplicated across updates.
class CodexStreamReader {
  final Set<String> _knownAgents = {};
  final Set<String> _finishedAgents = {};

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
          case 'collab_tool_call':
            return _readCollaboration(item);
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

  List<Map<String, dynamic>> _readCollaboration(Map<String, dynamic> item) {
    final tool = item['tool'] as String? ?? '';
    final sender = item['sender_thread_id'] as String?;
    final prompt = item['prompt'] as String? ?? '';
    final states =
        (item['agents_states'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final recipients = {
      ...(item['receiver_thread_ids'] as List? ?? const []).whereType<String>(),
      ...states.keys,
    };
    final events = <Map<String, dynamic>>[
      {
        'type': 'toolUse',
        'name': tool,
        'input': {'description': prompt},
      },
    ];
    for (final id in recipients) {
      if (id.isEmpty) continue;
      if (_knownAgents.add(id)) {
        events.add({
          'type': 'subagentStarted',
          'id': id,
          if (_knownAgents.contains(sender)) 'parentSubagentId': sender,
          'agentType': 'codex',
          'ask': prompt,
          'prompt': prompt,
        });
      }
      final state = (states[id] as Map?)?.cast<String, dynamic>();
      final status = state?['status'] as String?;
      switch (status) {
        case 'completed':
        case 'errored':
        case 'interrupted':
        case 'shutdown':
        case 'not_found':
          if (_finishedAgents.add(id)) {
            events.add({
              'type': 'subagentFinished',
              'id': id,
              'result': state?['message'] as String? ?? '',
              'isError': status != 'completed',
            });
          }
        case 'pending_init':
        case 'running':
          // A follow-up can reactivate an existing child without spawning
          // a second node. Null status conveys no lifecycle transition.
          if (_finishedAgents.remove(id)) {
            events.add({'type': 'subagentReasoning', 'id': id, 'text': ''});
          }
      }
    }
    return events;
  }
}

int _usageInt(Object? value) => (value as num?)?.toInt() ?? 0;
