import 'package:keel_ui/src/modules/projects/model/chat_reference_kind.dart';

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
}
