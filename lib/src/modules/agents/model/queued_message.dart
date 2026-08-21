import 'package:flutter/foundation.dart';

/// Something the user wrote WHILE the agent was still working on the
/// previous turn.
///
/// The local CLIs are one-shot per turn (`claude -p`, `codex exec`): there
/// is no stdin to inject a mid-turn message into. So a message typed during
/// a turn waits here and goes out as the next turn, instead of the composer
/// locking the user out until the model is done.
class QueuedMessage {
  final String text;

  /// Attachments already stored by `ChatAttachmentStore` — they wait with
  /// the message they belong to.
  final List<String> imagePaths;

  const QueuedMessage({required this.text, this.imagePaths = const []});

  QueuedMessage copyWith({String? text, List<String>? imagePaths}) {
    return QueuedMessage(
      text: text ?? this.text,
      imagePaths: imagePaths ?? this.imagePaths,
    );
  }

  Map<String, dynamic> toJson() => {'text': text, 'imagePaths': imagePaths};

  factory QueuedMessage.fromJson(Map<String, dynamic> json) {
    return QueuedMessage(
      text: json['text'] as String? ?? '',
      imagePaths: (json['imagePaths'] as List?)?.cast<String>() ?? const [],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueuedMessage &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          listEquals(imagePaths, other.imagePaths);

  @override
  int get hashCode => Object.hash(text, Object.hashAll(imagePaths));

  @override
  String toString() =>
      'QueuedMessage(text: $text, images: ${imagePaths.length})';
}
