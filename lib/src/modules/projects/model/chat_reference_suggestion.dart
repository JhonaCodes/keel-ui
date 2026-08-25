import 'package:keel_ui/src/modules/projects/model/chat_reference_kind.dart';

/// Una opción visible del autocomplete y el texto exacto que inserta.
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
}
