import 'package:keel_ui/src/modules/agents/model/file_edit.dart';

/// One piece of an assistant turn, in the order the model emitted it.
///
/// A turn is a SEQUENCE, not a bubble that gets rewritten: the model writes,
/// edits a file, writes again. Holding the answer as a single `text` plus a
/// separate list of edits loses that order — and, worse, made every new chunk
/// overwrite the edits captured by the previous one, so the editor card
/// vanished as soon as the model kept talking.
///
/// Blocks already emitted are immutable; only the last text block grows.
sealed class MessageBlock {
  const MessageBlock();

  Map<String, dynamic> toJson();

  /// Fails loud on an unknown kind, like the rest of this model does with a
  /// bad role or a missing timestamp: a block we can't render is a bug in
  /// whatever wrote it, not something to silently drop from the thread.
  static MessageBlock fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String?;
    return switch (kind) {
      'text' => MessageTextBlock(json['text'] as String? ?? ''),
      'fileEdit' => MessageFileEditBlock(
        FileEdit.fromJson(json['edit'] as Map<String, dynamic>),
      ),
      _ => throw FormatException('Unknown message block kind: $kind'),
    };
  }
}

/// A run of prose. The only block that grows while the turn streams.
final class MessageTextBlock extends MessageBlock {
  const MessageTextBlock(this.text);

  final String text;

  MessageTextBlock copyWith({String? text}) =>
      MessageTextBlock(text ?? this.text);

  @override
  Map<String, dynamic> toJson() => {'kind': 'text', 'text': text};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageTextBlock &&
          runtimeType == other.runtimeType &&
          text == other.text;

  @override
  int get hashCode => Object.hash('text', text);

  @override
  String toString() => 'MessageTextBlock(${text.length} chars)';
}

/// A file the turn touched, rendered as its own reviewable card right where
/// it happened.
final class MessageFileEditBlock extends MessageBlock {
  const MessageFileEditBlock(this.edit);

  final FileEdit edit;

  MessageFileEditBlock copyWith({FileEdit? edit}) =>
      MessageFileEditBlock(edit ?? this.edit);

  @override
  Map<String, dynamic> toJson() => {'kind': 'fileEdit', 'edit': edit.toJson()};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageFileEditBlock &&
          runtimeType == other.runtimeType &&
          edit == other.edit;

  @override
  int get hashCode => Object.hash('fileEdit', edit);

  @override
  String toString() => 'MessageFileEditBlock(${edit.path})';
}
