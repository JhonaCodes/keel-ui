import 'package:keel_ui/src/integrations/llm/llm.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';

const _historyMessageLimit = 32;
const _historyCharacterLimit = 24000;
const _historyMessageCharacterLimit = 6000;

/// Rebuilds a bounded, single-thread history for stateless API providers.
///
/// Callers decide which message is the current turn; it must be sent as the
/// prompt, not duplicated in this history. The newest entries win when the
/// fixed character budget is exhausted, which preserves a just-asked
/// confirmation and its reply such as "sí".
List<LlmConversationMessage> remoteConversationHistory(
  Iterable<ChatMessage> messages, {
  bool includeAssistantAuthor = false,
}) {
  final entries = <LlmConversationMessage>[];
  for (final message in messages) {
    if (message.role == ChatRole.error) continue;
    final text = message.text.trim();
    if (text.isEmpty) continue;
    final content = text.length <= _historyMessageCharacterLimit
        ? text
        : '${text.substring(0, _historyMessageCharacterLimit)}\n'
              '[mensaje anterior truncado por Keel]';
    entries.add(
      LlmConversationMessage(
        role: switch (message.role) {
          ChatRole.user => LlmConversationRole.user,
          ChatRole.assistant => LlmConversationRole.assistant,
          ChatRole.system => LlmConversationRole.system,
          ChatRole.error => throw StateError('Los errores no son contexto'),
        },
        content:
            includeAssistantAuthor &&
                message.role == ChatRole.assistant &&
                message.authorProfileId != null
            ? '[@${message.authorProfileId}]\n$content'
            : content,
      ),
    );
  }

  final first = (entries.length - _historyMessageLimit)
      .clamp(0, entries.length)
      .toInt();
  final recent = entries.sublist(first);
  var usedCharacters = 0;
  final boundedNewestFirst = <LlmConversationMessage>[];
  for (final entry in recent.reversed) {
    if (usedCharacters + entry.content.length > _historyCharacterLimit &&
        boundedNewestFirst.isNotEmpty) {
      continue;
    }
    boundedNewestFirst.add(entry);
    usedCharacters += entry.content.length;
  }
  return boundedNewestFirst.reversed.toList();
}
