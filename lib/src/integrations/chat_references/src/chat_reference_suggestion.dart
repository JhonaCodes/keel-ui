part of '../chat_references.dart';

/// Una opción visible del autocomplete y el texto exacto que inserta.
///
/// Viaja serializada hacia la ventana de Keel AI: ese engine no tiene base
/// de datos ([LocalDatabase.markUnavailable]), así que no puede armar la
/// lista por su cuenta — se la arma el engine principal y se la manda.
class ChatReferenceSuggestion {
  const ChatReferenceSuggestion({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.insertion,
    required this.searchText,
  });

  final ChatReferenceKind kind;
  final String title;
  final String subtitle;
  final String insertion;
  final String searchText;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'title': title,
    'subtitle': subtitle,
    'insertion': insertion,
    'searchText': searchText,
  };

  factory ChatReferenceSuggestion.fromJson(Map<String, dynamic> json) {
    return ChatReferenceSuggestion(
      kind: ChatReferenceKind.values.byName(json['kind'] as String),
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      insertion: json['insertion'] as String,
      searchText: json['searchText'] as String,
    );
  }
}
