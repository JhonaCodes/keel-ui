import 'package:keel_ui/src/integrations/llm/llm.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';

/// Un hilo 1:1: dos voces, y el turno actual es lo único que importa de
/// verdad.
const _historyMessageLimit = 32;
const _historyCharacterLimit = 24000;

/// Un canal con varios miembros gasta el presupuesto mucho más rápido: cada
/// vuelta del workflow suma la respuesta de un agente distinto, y con los
/// topes de un 1:1 el aporte del primer especialista se cae del contexto
/// justo cuando el último lo necesita para cerrar. Sube el techo solo en ese
/// caso — un chat de a dos no tiene por qué pagarlo.
const _multiAuthorMessageLimit = 48;
const _multiAuthorCharacterLimit = 40000;

const _historyMessageCharacterLimit = 6000;

/// Rebuilds a bounded, single-thread history for stateless API providers.
///
/// Callers decide which message is the current turn; it must be sent as the
/// prompt, not duplicated in this history. The newest entries win when the
/// fixed character budget is exhausted, which preserves a just-asked
/// confirmation and its reply such as "sí".
///
/// [handleOf] traduce el `authorProfileId` de un mensaje al handle con el
/// que se lo conoce en el canal. Es obligatorio para que
/// [includeAssistantAuthor] sirva de algo: el id es un UUID, y firmar
/// `[@2f9c1a7e-…]` es lo mismo que no firmar — el agente no puede seguir
/// quién dijo qué, aunque el system prompt le prometa que el hilo viene
/// firmado. Un id que ya no resuelve (un miembro que salió del proyecto) se
/// deja sin firma antes que mentir con un handle prestado.
List<LlmConversationMessage> remoteConversationHistory(
  Iterable<ChatMessage> messages, {
  bool includeAssistantAuthor = false,
  String? Function(String profileId)? handleOf,
}) {
  final entries = <LlmConversationMessage>[];
  final authors = <String>{};
  for (final message in messages) {
    if (message.role == ChatRole.error || message.role == ChatRole.blocked) {
      continue;
    }
    final text = message.text.trim();
    if (text.isEmpty) continue;
    final content = text.length <= _historyMessageCharacterLimit
        ? text
        : '${text.substring(0, _historyMessageCharacterLimit)}\n'
              '[mensaje anterior truncado por Keel]';
    final authorId = message.authorProfileId;
    if (authorId != null) authors.add(authorId);
    final handle = includeAssistantAuthor && authorId != null
        ? (handleOf == null ? authorId : handleOf(authorId))
        : null;
    entries.add(
      LlmConversationMessage(
        role: switch (message.role) {
          ChatRole.user => LlmConversationRole.user,
          ChatRole.assistant => LlmConversationRole.assistant,
          ChatRole.system => LlmConversationRole.system,
          ChatRole.error ||
          ChatRole.blocked => throw StateError('Los errores no son contexto'),
        },
        content:
            handle != null &&
                handle.isNotEmpty &&
                message.role == ChatRole.assistant
            ? '[@$handle]\n$content'
            : content,
      ),
    );
  }

  final multiAuthor = authors.length > 1;
  final messageLimit = multiAuthor
      ? _multiAuthorMessageLimit
      : _historyMessageLimit;
  final characterLimit = multiAuthor
      ? _multiAuthorCharacterLimit
      : _historyCharacterLimit;

  final first = (entries.length - messageLimit)
      .clamp(0, entries.length)
      .toInt();
  final recent = entries.sublist(first);
  var usedCharacters = 0;
  final boundedNewestFirst = <LlmConversationMessage>[];
  for (final entry in recent.reversed) {
    if (usedCharacters + entry.content.length > characterLimit &&
        boundedNewestFirst.isNotEmpty) {
      continue;
    }
    boundedNewestFirst.add(entry);
    usedCharacters += entry.content.length;
  }
  return boundedNewestFirst.reversed.toList();
}
