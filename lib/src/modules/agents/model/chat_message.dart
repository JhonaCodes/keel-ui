import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/modules/agents/model/file_edit.dart';

enum ChatRole {
  user,
  assistant,
  error,

  /// Written by the app itself, not the human or the model — e.g. the
  /// automatic "you forgot the block" retry prompt. Rendered distinctly from
  /// [user] so it's never mistaken for something the human typed.
  system,
}

class ChatMessage {
  final ChatRole role;
  final String text;
  final DateTime timestamp;
  final double? costUsd;
  final int? durationMs;
  final String? reasoning;
  final List<FileEdit> fileEdits;

  /// Images the user attached to this message, as paths inside app storage
  /// (see `ChatAttachmentStore`) — never the original path they were
  /// dragged from, which is often a temp folder the OS wipes. The bubble
  /// renders them as bounded previews; the model gets the PATHS in the
  /// prompt and reads the bytes itself with its Read tool.
  final List<String> imagePaths;

  /// Which registered profile wrote this, when the thread has more than one
  /// author (a workstation channel). Null in a 1:1 agent chat, where the
  /// single assistant needs no attribution.
  final String? authorProfileId;

  /// Index of the workflow step this message belongs to, so the bubble can
  /// show *why* this author is talking. Null outside a workflow run.
  final int? stepIndex;

  /// Set when this message answers another member's `@handle` consultation,
  /// naming the profile that asked. Renders as a nested aside in the thread.
  final String? consultOfProfileId;

  const ChatMessage({
    required this.role,
    required this.text,
    required this.timestamp,
    this.costUsd,
    this.durationMs,
    this.reasoning,
    this.fileEdits = const [],
    this.imagePaths = const [],
    this.authorProfileId,
    this.stepIndex,
    this.consultOfProfileId,
  });

  Map<String, dynamic> toJson() => {
    'role': role.name,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
    'costUsd': costUsd,
    'durationMs': durationMs,
    'reasoning': reasoning,
    'fileEdits': fileEdits.map((edit) => edit.toJson()).toList(),
    'imagePaths': imagePaths,
    'authorProfileId': authorProfileId,
    'stepIndex': stepIndex,
    'consultOfProfileId': consultOfProfileId,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: ChatRole.values.byName(json['role'] as String),
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      costUsd: (json['costUsd'] as num?)?.toDouble(),
      durationMs: json['durationMs'] as int?,
      reasoning: json['reasoning'] as String?,
      fileEdits:
          (json['fileEdits'] as List?)
              ?.map((entry) => FileEdit.fromJson(entry as Map<String, dynamic>))
              .toList() ??
          const [],
      imagePaths: (json['imagePaths'] as List?)?.cast<String>() ?? const [],
      authorProfileId: json['authorProfileId'] as String?,
      stepIndex: json['stepIndex'] as int?,
      consultOfProfileId: json['consultOfProfileId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          role == other.role &&
          text == other.text &&
          timestamp == other.timestamp &&
          costUsd == other.costUsd &&
          durationMs == other.durationMs &&
          reasoning == other.reasoning &&
          listEquals(fileEdits, other.fileEdits) &&
          listEquals(imagePaths, other.imagePaths) &&
          authorProfileId == other.authorProfileId &&
          stepIndex == other.stepIndex &&
          consultOfProfileId == other.consultOfProfileId;

  @override
  int get hashCode => Object.hash(
    role,
    text,
    timestamp,
    costUsd,
    durationMs,
    reasoning,
    Object.hashAll(fileEdits),
    Object.hashAll(imagePaths),
    authorProfileId,
    stepIndex,
    consultOfProfileId,
  );

  @override
  String toString() =>
      'ChatMessage(role: $role, text: $text, timestamp: $timestamp, costUsd: $costUsd, '
      'durationMs: $durationMs, reasoning: $reasoning, fileEdits: ${fileEdits.length}, '
      'images: ${imagePaths.length}, '
      'author: $authorProfileId, step: $stepIndex, consultOf: $consultOfProfileId)';
}
