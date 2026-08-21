import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/model/permission_request.dart';
import 'package:keel_ui/src/modules/stations/model/task_live_turn.dart';

enum StationTaskStatus { running, finished, failed }

StationTaskStatus _statusFromName(String? name) {
  return switch (name) {
    'finished' => StationTaskStatus.finished,
    'failed' => StationTaskStatus.failed,
    _ => StationTaskStatus.running,
  };
}

/// One run of a station's workflow: the visible thread plus the CLI sessions
/// it opened. Sessions live here, not on the station, so starting a new task
/// starts every member from a clean session and a clean screen — nothing is
/// carried over from the previous task.
class StationTask {
  final String id;
  final String title;
  final DateTime createdAt;
  final StationTaskStatus status;
  final List<ChatMessage> messages;
  final Map<String, String> sessionsByProfileId;

  /// Members added ONLY to this task ("traé un auditor para esta tarea").
  /// The station's own roster is untouched — other tasks never see them.
  final List<String> extraProfileIds;
  final int currentStepIndex;
  final bool isRunning;

  /// Accumulated cost of every CLI turn this task ran (USD), total and
  /// broken down by member profile — the ledger that makes the economics of
  /// a channel visible instead of invisible.
  final double costUsd;
  final Map<String, double> costByProfileId;

  /// Context the last turn of this task reported. Per task, not per station:
  /// a new task opens fresh sessions, so its context starts from zero again.
  final int? contextUsedTokens;
  final int? contextWindowTokens;

  /// A tool one of the members tried to use and was not allowed to. Held on
  /// the task so the thread can ask you about it once, instead of the turn
  /// silently failing. Deliberately not persisted: a question you never
  /// answered is stale by the time the app reopens.
  final PermissionRequest? pendingPermission;

  /// The turn in flight: who holds it, what it is reasoning, which tool it has
  /// open. Not persisted — see [TaskLiveTurn].
  final TaskLiveTurn? liveTurn;

  const StationTask({
    required this.id,
    required this.title,
    required this.createdAt,
    this.status = StationTaskStatus.running,
    this.messages = const [],
    this.sessionsByProfileId = const {},
    this.extraProfileIds = const [],
    this.currentStepIndex = 0,
    this.isRunning = false,
    this.costUsd = 0,
    this.costByProfileId = const {},
    this.contextUsedTokens,
    this.contextWindowTokens,
    this.pendingPermission,
    this.liveTurn,
  });

  /// How full the context is, 0..1, or null while nothing has reported yet.
  double? get contextUsageRatio {
    final used = contextUsedTokens;
    final window = contextWindowTokens;
    if (used == null || window == null || window <= 0) return null;
    return (used / window).clamp(0.0, 1.0);
  }

  StationTask copyWith({
    String? title,
    StationTaskStatus? status,
    List<ChatMessage>? messages,
    Map<String, String>? sessionsByProfileId,
    List<String>? extraProfileIds,
    int? currentStepIndex,
    bool? isRunning,
    double? costUsd,
    Map<String, double>? costByProfileId,
    int? contextUsedTokens,
    int? contextWindowTokens,
    PermissionRequest? pendingPermission,
    bool clearPendingPermission = false,
    TaskLiveTurn? liveTurn,
    bool clearLiveTurn = false,
  }) {
    return StationTask(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      status: status ?? this.status,
      messages: messages ?? this.messages,
      sessionsByProfileId: sessionsByProfileId ?? this.sessionsByProfileId,
      extraProfileIds: extraProfileIds ?? this.extraProfileIds,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      isRunning: isRunning ?? this.isRunning,
      costUsd: costUsd ?? this.costUsd,
      costByProfileId: costByProfileId ?? this.costByProfileId,
      contextUsedTokens: contextUsedTokens ?? this.contextUsedTokens,
      contextWindowTokens: contextWindowTokens ?? this.contextWindowTokens,
      pendingPermission: clearPendingPermission
          ? null
          : (pendingPermission ?? this.pendingPermission),
      liveTurn: clearLiveTurn ? null : (liveTurn ?? this.liveTurn),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'messages': messages.map((message) => message.toJson()).toList(),
    'sessionsByProfileId': sessionsByProfileId,
    'extraProfileIds': extraProfileIds,
    'currentStepIndex': currentStepIndex,
    'isRunning': isRunning,
    'costUsd': costUsd,
    'costByProfileId': costByProfileId,
    'contextUsedTokens': contextUsedTokens,
    'contextWindowTokens': contextWindowTokens,
  };

  factory StationTask.fromJson(Map<String, dynamic> json) {
    return StationTask(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: _statusFromName(json['status'] as String?),
      messages: (json['messages'] as List? ?? const [])
          .map((entry) => ChatMessage.fromJson(entry as Map<String, dynamic>))
          .toList(),
      sessionsByProfileId:
          (json['sessionsByProfileId'] as Map?)?.cast<String, String>() ??
          const {},
      extraProfileIds:
          (json['extraProfileIds'] as List?)?.cast<String>() ?? const [],
      currentStepIndex: json['currentStepIndex'] as int? ?? 0,
      isRunning: json['isRunning'] as bool? ?? false,
      costUsd: (json['costUsd'] as num?)?.toDouble() ?? 0,
      costByProfileId:
          (json['costByProfileId'] as Map?)?.map(
            (key, value) => MapEntry(key as String, (value as num).toDouble()),
          ) ??
          const {},
      contextUsedTokens: json['contextUsedTokens'] as int?,
      contextWindowTokens: json['contextWindowTokens'] as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StationTask &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          createdAt == other.createdAt &&
          status == other.status &&
          listEquals(messages, other.messages) &&
          mapEquals(sessionsByProfileId, other.sessionsByProfileId) &&
          listEquals(extraProfileIds, other.extraProfileIds) &&
          currentStepIndex == other.currentStepIndex &&
          isRunning == other.isRunning &&
          costUsd == other.costUsd &&
          mapEquals(costByProfileId, other.costByProfileId) &&
          contextUsedTokens == other.contextUsedTokens &&
          contextWindowTokens == other.contextWindowTokens &&
          pendingPermission == other.pendingPermission &&
          liveTurn == other.liveTurn;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    createdAt,
    status,
    Object.hashAll(messages),
    Object.hashAll(
      sessionsByProfileId.entries.map((e) => '${e.key}:${e.value}'),
    ),
    Object.hashAll(extraProfileIds),
    currentStepIndex,
    isRunning,
    costUsd,
    Object.hashAll(
      costByProfileId.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    contextUsedTokens,
    contextWindowTokens,
    pendingPermission,
    liveTurn,
  );

  @override
  String toString() =>
      'StationTask(id: $id, title: $title, status: ${status.name}, '
      'messages: ${messages.length}, step: $currentStepIndex, '
      'running: $isRunning)';
}
