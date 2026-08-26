part of '../chat_references.dart';

/// El token incompleto que rodea al cursor y debe alimentar el autocomplete.
class ChatReferenceQuery {
  const ChatReferenceQuery({
    required this.kind,
    required this.text,
    required this.start,
    required this.end,
  });

  final ChatReferenceKind kind;
  final String text;
  final int start;
  final int end;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'text': text,
    'start': start,
    'end': end,
  };

  factory ChatReferenceQuery.fromJson(Map<String, dynamic> json) {
    return ChatReferenceQuery(
      kind: ChatReferenceKind.values.byName(json['kind'] as String),
      text: json['text'] as String,
      start: json['start'] as int,
      end: json['end'] as int,
    );
  }
}
