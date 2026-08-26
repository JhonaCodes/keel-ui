import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/llm/llm.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/service/remote_conversation_history.dart';

final _time = DateTime(2026, 8, 27);

ChatMessage _message(ChatRole role, String text, {String? author}) {
  return ChatMessage(
    role: role,
    text: text,
    timestamp: _time,
    authorProfileId: author,
  );
}

void main() {
  test(
    'preserves only usable thread entries and identifies project authors',
    () {
      final history = remoteConversationHistory([
        _message(ChatRole.user, '¿Aplicamos la migración?'),
        _message(
          ChatRole.assistant,
          'Encontré tres archivos. ¿La aplico?',
          author: 'implementer',
        ),
        _message(ChatRole.error, 'No debe llegar al proveedor.'),
      ], includeAssistantAuthor: true);

      expect(history, [
        const LlmConversationMessage(
          role: LlmConversationRole.user,
          content: '¿Aplicamos la migración?',
        ),
        const LlmConversationMessage(
          role: LlmConversationRole.assistant,
          content: '[@implementer]\nEncontré tres archivos. ¿La aplico?',
        ),
      ]);
    },
  );

  test('keeps the latest context when the fixed remote budget fills up', () {
    String large(String label) => '$label:${List.filled(6000, 'x').join()}';
    final history = remoteConversationHistory([
      _message(ChatRole.user, large('1')),
      _message(ChatRole.assistant, large('2')),
      _message(ChatRole.user, large('3')),
      _message(ChatRole.assistant, large('4')),
      _message(ChatRole.user, 'Sí, aplicalo.'),
    ]);

    expect(history.length, 4);
    expect(history.last.content, 'Sí, aplicalo.');
    expect(history.first.content, startsWith('2:'));
  });
}
