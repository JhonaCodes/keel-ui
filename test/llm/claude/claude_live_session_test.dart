import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_core/integrations/llm/claude/claude_live_session.dart';
import 'package:keel_core/integrations/llm/llm.dart';

import '../support/fake_cli_process.dart';

const _spec = LlmTurnSpec(
  prompt: '',
  workingDirectory: '.',
  model: 'sonnet',
  fullFileSystemAccess: false,
  effort: 'medium',
);

/// The sequence CLI 2.1.280 emits for a turn that leaves a background
/// subagent running: an early `result` while the task is pending, then the
/// task finishes, the model is re-invoked and a second `result` closes it.
const _backgroundTurn = r'''#!/bin/sh
while IFS= read -r line; do
  echo '{"type":"system","subtype":"init","session_id":"s1","model":"sonnet"}'
  echo '{"type":"system","subtype":"background_tasks_changed","tasks":[{"task_id":"a1","task_type":"local_agent"}]}'
  echo '{"type":"assistant","message":{"content":[{"type":"text","text":"WAITING"}]}}'
  echo '{"type":"result","subtype":"success","is_error":false,"result":"WAITING"}'
  sleep 1
  echo '{"type":"system","subtype":"background_tasks_changed","tasks":[]}'
  echo '{"type":"system","subtype":"init","session_id":"s1","model":"sonnet"}'
  echo '{"type":"assistant","message":{"content":[{"type":"text","text":"FINISHED"}]}}'
  echo '{"type":"result","subtype":"success","is_error":false,"result":"FINISHED"}'
done
''';

void main() {
  test(
    'with a background task pending, the turn does not end at the first result',
    () async {
      final fakeBin = createFakeCliBin('claude', _backgroundTurn);
      addTearDown(() => fakeBin.deleteSync(recursive: true));

      final session = await ClaudeLiveSession.start(
        _spec,
        userPath: fakeCliUserPath(fakeBin),
      );
      final seen = <String>[];
      final turnEnded = Completer<void>();
      final subscription = session.events.listen((event) {
        final type = event['type'] as String;
        seen.add(type == 'assistantText' ? 'text:${event['text']}' : type);
        if (type == 'turnEnded' && !turnEnded.isCompleted) {
          turnEnded.complete();
        }
      });
      addTearDown(subscription.cancel);

      session.send('hola');
      await turnEnded.future.timeout(const Duration(seconds: 10));
      await session.close();

      // Ending at the first `result` is the ghost: FINISHED and whatever the
      // task did would arrive with the chat already marked idle.
      expect(
        seen.where(
          (type) => type.startsWith('text:') || type == 'turnEnded',
        ),
        ['text:WAITING', 'text:FINISHED', 'turnEnded'],
      );
    },
  );
}
