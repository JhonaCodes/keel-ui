import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/modules/agents/model/file_edit.dart';
import 'package:keel_ui/src/modules/agents/model/message_block.dart';

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

  /// The turn's contents, in the order the model emitted them: prose, then
  /// the file it edited, then the prose that followed. This is the canonical
  /// field — [text] and [fileEdits] are views over it.
  final List<MessageBlock> blocks;

  final DateTime timestamp;
  final double? costUsd;
  final int? durationMs;
  final String? reasoning;

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

  /// Resolution node this message belongs to. Node ids survive graph
  /// reformulation; a positional workflow index does not.
  final String? workNodeId;

  /// Set when this message answers another member's `@handle` consultation,
  /// naming the profile that asked. Renders as a nested aside in the thread.
  final String? consultOfProfileId;

  /// The plain shape: one run of prose, optionally followed by the files the
  /// turn touched. Everything that isn't a streamed answer — a user prompt,
  /// an error, a system note — is built this way.
  ChatMessage({
    required this.role,
    required String text,
    required this.timestamp,
    this.costUsd,
    this.durationMs,
    this.reasoning,
    List<FileEdit> fileEdits = const [],
    this.imagePaths = const [],
    this.authorProfileId,
    this.workNodeId,
    this.consultOfProfileId,
  }) : blocks = [
         if (text.isNotEmpty) MessageTextBlock(text),
         for (final edit in fileEdits) MessageFileEditBlock(edit),
       ];

  /// The ordered shape, for a streamed answer that interleaves prose and
  /// edits.
  ChatMessage.fromBlocks({
    required this.role,
    required this.blocks,
    required this.timestamp,
    this.costUsd,
    this.durationMs,
    this.reasoning,
    this.imagePaths = const [],
    this.authorProfileId,
    this.workNodeId,
    this.consultOfProfileId,
  });

  /// All the prose, concatenated. Same characters the single `text` field
  /// used to hold, so every reader of a message — the remote conversation
  /// history, the bubble width tier, the assistant snapshot — is unchanged.
  ///
  /// Cached: a message is immutable, and this is read on every rebuild.
  late final String text = [
    for (final block in blocks)
      if (block is MessageTextBlock) block.text,
  ].join();

  /// Every file this turn touched, in order.
  late final List<FileEdit> fileEdits = [
    for (final block in blocks)
      if (block is MessageFileEditBlock) block.edit,
  ];

  /// The next slice of a streamed answer, appended without disturbing what
  /// came before.
  ///
  /// [fileEdits] land FIRST because they already happened: the collector
  /// captures them on the tool-use event and hands them over with the next
  /// text chunk. Landing them first also closes the open text block, so the
  /// prose that follows an edit becomes its own block instead of being glued
  /// onto the paragraph that preceded the card.
  ChatMessage appendingChunk({
    required String text,
    List<FileEdit> fileEdits = const [],
    String? reasoning,
  }) {
    final next = [
      ...blocks,
      for (final edit in fileEdits) MessageFileEditBlock(edit),
    ];
    if (text.isNotEmpty) {
      final last = next.isEmpty ? null : next.last;
      if (last is MessageTextBlock) {
        next[next.length - 1] = MessageTextBlock(last.text + text);
      } else {
        next.add(MessageTextBlock(text));
      }
    }
    return copyWith(blocks: next, reasoning: reasoning ?? this.reasoning);
  }

  ChatMessage copyWith({
    ChatRole? role,
    List<MessageBlock>? blocks,
    DateTime? timestamp,
    double? costUsd,
    int? durationMs,
    String? reasoning,
    List<String>? imagePaths,
    String? authorProfileId,
    String? workNodeId,
    String? consultOfProfileId,
  }) {
    return ChatMessage.fromBlocks(
      role: role ?? this.role,
      blocks: blocks ?? this.blocks,
      timestamp: timestamp ?? this.timestamp,
      costUsd: costUsd ?? this.costUsd,
      durationMs: durationMs ?? this.durationMs,
      reasoning: reasoning ?? this.reasoning,
      imagePaths: imagePaths ?? this.imagePaths,
      authorProfileId: authorProfileId ?? this.authorProfileId,
      workNodeId: workNodeId ?? this.workNodeId,
      consultOfProfileId: consultOfProfileId ?? this.consultOfProfileId,
    );
  }

  Map<String, dynamic> toJson() => {
    'role': role.name,
    'blocks': blocks.map((block) => block.toJson()).toList(),
    'timestamp': timestamp.toIso8601String(),
    'costUsd': costUsd,
    'durationMs': durationMs,
    'reasoning': reasoning,
    'imagePaths': imagePaths,
    'authorProfileId': authorProfileId,
    'workNodeId': workNodeId,
    'consultOfProfileId': consultOfProfileId,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawBlocks = json['blocks'] as List?;
    // Threads written before the turn was a sequence: prose first, then the
    // edits. That IS what those messages rendered, so nothing moves.
    final blocks = rawBlocks != null
        ? [
            for (final entry in rawBlocks)
              MessageBlock.fromJson(entry as Map<String, dynamic>),
          ]
        : _legacyBlocks(json);
    return ChatMessage.fromBlocks(
      role: ChatRole.values.byName(json['role'] as String),
      blocks: blocks,
      timestamp: DateTime.parse(json['timestamp'] as String),
      costUsd: (json['costUsd'] as num?)?.toDouble(),
      durationMs: json['durationMs'] as int?,
      reasoning: json['reasoning'] as String?,
      imagePaths: (json['imagePaths'] as List?)?.cast<String>() ?? const [],
      authorProfileId: json['authorProfileId'] as String?,
      workNodeId: json['workNodeId'] as String?,
      consultOfProfileId: json['consultOfProfileId'] as String?,
    );
  }

  static List<MessageBlock> _legacyBlocks(Map<String, dynamic> json) {
    final text = json['text'] as String? ?? '';
    return [
      if (text.isNotEmpty) MessageTextBlock(text),
      for (final entry in (json['fileEdits'] as List?) ?? const [])
        MessageFileEditBlock(FileEdit.fromJson(entry as Map<String, dynamic>)),
    ];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          role == other.role &&
          listEquals(blocks, other.blocks) &&
          timestamp == other.timestamp &&
          costUsd == other.costUsd &&
          durationMs == other.durationMs &&
          reasoning == other.reasoning &&
          listEquals(imagePaths, other.imagePaths) &&
          authorProfileId == other.authorProfileId &&
          workNodeId == other.workNodeId &&
          consultOfProfileId == other.consultOfProfileId;

  @override
  int get hashCode => Object.hash(
    role,
    Object.hashAll(blocks),
    timestamp,
    costUsd,
    durationMs,
    reasoning,
    Object.hashAll(imagePaths),
    authorProfileId,
    workNodeId,
    consultOfProfileId,
  );

  @override
  String toString() =>
      'ChatMessage(role: $role, blocks: ${blocks.length}, text: $text, '
      'timestamp: $timestamp, costUsd: $costUsd, durationMs: $durationMs, '
      'reasoning: $reasoning, fileEdits: ${fileEdits.length}, '
      'images: ${imagePaths.length}, '
      'author: $authorProfileId, node: $workNodeId, consultOf: $consultOfProfileId)';
}
