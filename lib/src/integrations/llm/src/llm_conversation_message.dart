part of '../llm.dart';

/// A persisted thread entry made safe to send to a stateless remote model.
///
/// Local CLIs keep their own native session ids. API providers do not, so
/// callers pass only the bounded, session-scoped entries that precede the
/// current [LlmTurnSpec.prompt].
enum LlmConversationRole { user, assistant, system }

class LlmConversationMessage {
  final LlmConversationRole role;
  final String content;

  const LlmConversationMessage({required this.role, required this.content});

  Map<String, String> toJson() => {'role': role.name, 'content': content};

  factory LlmConversationMessage.fromJson(Map<String, dynamic> json) {
    return LlmConversationMessage(
      role: LlmConversationRole.values.byName(json['role'] as String),
      content: json['content'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LlmConversationMessage &&
          role == other.role &&
          content == other.content;

  @override
  int get hashCode => Object.hash(role, content);
}
