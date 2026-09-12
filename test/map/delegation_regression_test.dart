import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/claude_stream_events.dart';
import 'package:keel_ui/src/integrations/llm/codex/codex_stream_reader.dart';
import 'package:keel_ui/src/integrations/task_runner/task_runner.dart';
import 'package:keel_ui/src/modules/projects/model/thread_entry.dart';
import 'package:keel_ui/src/modules/projects/model/session_subagent.dart';

void main() {
  test(
    'background launch acknowledgement keeps child active until notification',
    () {
      final reader = ClaudeStreamReader();
      reader.read({
        'type': 'assistant',
        'message': {
          'content': [
            {
              'type': 'tool_use',
              'id': 'child',
              'name': 'Agent',
              'input': {'run_in_background': true, 'prompt': 'Auditar'},
            },
          ],
        },
      });
      final started = reader.read({
        'type': 'system',
        'subtype': 'task_started',
        'task_id': 'task1',
        'tool_use_id': 'child',
        'task_type': 'local_agent',
        'is_backgrounded': true,
        'description': 'Auditar',
      });
      expect(started, isEmpty);
      expect(
        reader.read({
          'type': 'user',
          'message': {
            'content': [
              {
                'type': 'tool_result',
                'tool_use_id': 'child',
                'content': 'Launched',
              },
            ],
          },
        }),
        isEmpty,
      );
      final progress = reader.read({
        'type': 'system',
        'subtype': 'task_progress',
        'task_id': 'task1',
        'last_tool_name': 'Read',
      });
      expect(progress.single['type'], 'subagentToolUse');
      final end = {
        'type': 'system',
        'subtype': 'task_notification',
        'task_id': 'task1',
        'status': 'completed',
        'summary': 'Auditoría terminada',
      };
      expect(reader.read(end).single['result'], 'Auditoría terminada');
      expect(reader.read(end), isEmpty);
    },
  );

  test('task lifecycle registers agents without inventing Bash subagents', () {
    final reader = ClaudeStreamReader();
    expect(
      reader.read({
        'type': 'system',
        'subtype': 'task_started',
        'task_id': 'bash',
        'tool_use_id': 'bash1',
        'task_type': 'local_bash',
      }),
      isEmpty,
    );
    final event = reader.read({
      'type': 'system',
      'subtype': 'task_started',
      'task_id': 'task',
      'tool_use_id': 'child',
      'task_type': 'local_agent',
      'description': 'Auditar',
      'subagent_type': 'Explore',
    });
    expect(event.single['agentType'], 'Explore');
    expect(event.single['ask'], 'Auditar');
  });

  test('Claude Agent registers once and leaves tool activity after text', () {
    final reader = ClaudeStreamReader();
    final event = {
      'type': 'assistant',
      'message': {
        'content': [
          {'type': 'text', 'text': 'Voy a investigar.'},
          {
            'type': 'tool_use',
            'id': 'child',
            'name': 'Agent',
            'input': {'subagent_type': 'Explore', 'prompt': 'Revisar el chat'},
          },
        ],
      },
    };
    final events = reader.read(event).map(TaskEvent.fromMessage).toList();
    expect(events.first, isA<TaskAssistantText>());
    expect(events.whereType<TaskSubagentStarted>().single.id, 'child');
    expect(events.whereType<TaskToolUse>().single.name, 'Agent');
    expect(
      reader.read(event).where((e) => e['type'] == 'subagentStarted'),
      isEmpty,
    );
  });

  test('Claude preserves nested delegation parent and nested completion', () {
    final reader = ClaudeStreamReader();
    final opened = reader.read({
      'type': 'assistant',
      'parent_tool_use_id': 'child',
      'message': {
        'content': [
          {
            'type': 'tool_use',
            'id': 'grandchild',
            'name': 'Agent',
            'input': {'prompt': 'Auditar'},
          },
        ],
      },
    });
    expect(
      opened.singleWhere(
        (e) => e['type'] == 'subagentStarted',
      )['parentSubagentId'],
      'child',
    );
    final completed = reader.read({
      'type': 'user',
      'parent_tool_use_id': 'child',
      'message': {
        'content': [
          {
            'type': 'tool_result',
            'tool_use_id': 'grandchild',
            'content': 'Listo',
          },
        ],
      },
    });
    expect(completed.single['type'], 'subagentFinished');
    expect(completed.single['id'], 'grandchild');
  });

  test(
    'Codex spawn completion is not child completion; wait finishes once',
    () {
      final reader = CodexStreamReader();
      final spawned = reader.read({
        'type': 'item.completed',
        'item': {
          'id': 'i1',
          'type': 'collab_tool_call',
          'tool': 'spawn_agent',
          'sender_thread_id': 'root',
          'receiver_thread_ids': ['child'],
          'prompt': 'Revisar el chat',
          'status': 'completed',
          'agents_states': {
            'child': {'status': 'running', 'message': null},
          },
        },
      });
      expect(
        spawned.where((e) => e['type'] == 'subagentStarted').single['id'],
        'child',
      );
      expect(spawned.where((e) => e['type'] == 'subagentFinished'), isEmpty);
      final wait = {
        'type': 'item.completed',
        'item': {
          'id': 'i2',
          'type': 'collab_tool_call',
          'tool': 'wait',
          'sender_thread_id': 'root',
          'receiver_thread_ids': ['child'],
          'status': 'completed',
          'agents_states': {
            'child': {'status': 'completed', 'message': 'Verificado'},
          },
        },
      };
      expect(
        reader
            .read(wait)
            .where((e) => e['type'] == 'subagentFinished')
            .single['result'],
        'Verificado',
      );
      expect(
        reader.read(wait).where((e) => e['type'] == 'subagentFinished'),
        isEmpty,
      );
    },
  );

  test('default chat filter shows an active subagent', () {
    expect(
      const ThreadFilter().admitsSubagent(
        SessionSubagent(
          id: 'child',
          parentProfileId: 'owner',
          agentType: 'Explore',
          ask: 'Revisar',
          prompt: 'Revisar',
          startedAt: DateTime.utc(2026),
        ),
      ),
      isTrue,
    );
  });
}
