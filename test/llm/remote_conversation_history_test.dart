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
      final history = remoteConversationHistory(
        [
          _message(ChatRole.user, '¿Aplicamos la migración?'),
          _message(
            ChatRole.assistant,
            'Encontré tres archivos. ¿La aplico?',
            author: 'implementer',
          ),
          _message(ChatRole.error, 'No debe llegar al proveedor.'),
        ],
        includeAssistantAuthor: true,
        handleOf: (id) => id,
      );

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

  test('firma con el handle del miembro, no con su id', () {
    final history = remoteConversationHistory(
      [_message(ChatRole.assistant, 'Listo el paso.', author: 'perfil-uuid-1')],
      includeAssistantAuthor: true,
      handleOf: (id) => 'flutter-experto',
    );

    expect(history.single.content, '[@flutter-experto]\nListo el paso.');
  });

  test('un autor que ya no está en el canal viaja sin firma', () {
    final history = remoteConversationHistory(
      [_message(ChatRole.assistant, 'Lo dejé andando.', author: 'se-fue')],
      includeAssistantAuthor: true,
      handleOf: (id) => null,
    );

    expect(history.single.content, 'Lo dejé andando.');
  });

  test('un hilo de varios autores estira el presupuesto', () {
    String large(String label) => '$label:${List.filled(6000, 'x').join()}';
    final messages = [
      for (var i = 0; i < 8; i++)
        _message(
          i.isEven ? ChatRole.user : ChatRole.assistant,
          large('$i'),
          author: i.isEven ? null : 'agente-${i % 4}',
        ),
    ];

    final multi = remoteConversationHistory(messages);

    final solo = remoteConversationHistory([
      for (final message in messages)
        _message(
          message.role,
          message.text,
          author: message.authorProfileId == null ? null : 'unico',
        ),
    ]);
    expect(
      multi.length,
      greaterThan(solo.length),
      reason: 'con varias voces entra más historia, con una sola no cambia',
    );
  });
}
