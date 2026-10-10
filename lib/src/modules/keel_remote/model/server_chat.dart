/// The chat with Keel AI on a keel-server node, through `keelai.*` tasks:
/// keel-api only queues them, the node answers in `result_json`.
library;

import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/integrations/keel_api/keel_api.dart';

enum ServerChatRole { person, keelAi, notice }

@immutable
class ServerChatMessage {
  const ServerChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.at,
    this.failure,
  });

  final String id;
  final ServerChatRole role;

  /// What was said. Empty for a [ServerChatRole.notice], which the UI words
  /// from [failure].
  final String text;
  final DateTime at;

  /// Why a turn did not get its answer; only on a notice.
  final KeelApiFailure? failure;

  factory ServerChatMessage.fromJson(Map<String, dynamic> json) =>
      ServerChatMessage(
        id: json['id'] as String? ?? '',
        role: ServerChatRole.values.firstWhere(
          (role) => role.name == json['role'],
          orElse: () => ServerChatRole.notice,
        ),
        text: json['text'] as String? ?? '',
        at: KeelJson.decodeTimestamp(json['at']) ?? DateTime.now(),
        failure: switch (json['failure']) {
          final Map<String, dynamic> failure => KeelApiFailure.fromJson(
            failure,
          ),
          _ => null,
        },
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'role': role.name,
    'text': text,
    'at': at.toUtc().toIso8601String(),
    'failure': failure?.toJson(),
  };

  ServerChatMessage copyWith({
    String? id,
    ServerChatRole? role,
    String? text,
    DateTime? at,
    KeelApiFailure? failure,
  }) => ServerChatMessage(
    id: id ?? this.id,
    role: role ?? this.role,
    text: text ?? this.text,
    at: at ?? this.at,
    failure: failure ?? this.failure,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerChatMessage &&
          id == other.id &&
          role == other.role &&
          text == other.text &&
          at == other.at &&
          failure == other.failure;

  @override
  int get hashCode => Object.hash(id, role, text, at, failure);
}

/// One conversation with Keel AI on one server node.
@immutable
class ServerChatState {
  const ServerChatState({
    this.nodeId,
    this.conversationId,
    this.messages = const <ServerChatMessage>[],
    this.waiting = false,
    this.step,
    this.taskId,
  });

  /// The node written to; null until one is chosen.
  final String? nodeId;

  /// The conversation on that node; null before the first message opens it.
  final String? conversationId;
  final List<ServerChatMessage> messages;

  /// A message is on its way and Keel AI has not answered yet.
  final bool waiting;

  /// What the node reports Keel AI is doing while it answers.
  final String? step;

  /// The `keelai.send` task of the turn in course.
  final String? taskId;

  ServerChatState copyWith({
    String? nodeId,
    String? conversationId,
    List<ServerChatMessage>? messages,
    bool? waiting,
    String? step,
    bool clearStep = false,
    String? taskId,
    bool clearTaskId = false,
  }) => ServerChatState(
    nodeId: nodeId ?? this.nodeId,
    conversationId: conversationId ?? this.conversationId,
    messages: messages ?? this.messages,
    waiting: waiting ?? this.waiting,
    step: clearStep ? null : (step ?? this.step),
    taskId: clearTaskId ? null : (taskId ?? this.taskId),
  );

  factory ServerChatState.fromJson(Map<String, dynamic> json) =>
      ServerChatState(
        nodeId: json['node_id'] as String?,
        conversationId: json['conversation_id'] as String?,
        messages: <ServerChatMessage>[
          for (final row in json['messages'] as List<Object?>? ?? const [])
            if (row is Map<String, dynamic>) ServerChatMessage.fromJson(row),
        ],
        waiting: KeelJson.decodeBool(json['waiting']),
        step: json['step'] as String?,
        taskId: json['task_id'] as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'node_id': nodeId,
    'conversation_id': conversationId,
    'messages': messages.map((message) => message.toJson()).toList(),
    'waiting': waiting,
    'step': step,
    'task_id': taskId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerChatState &&
          nodeId == other.nodeId &&
          conversationId == other.conversationId &&
          listEquals(messages, other.messages) &&
          waiting == other.waiting &&
          step == other.step &&
          taskId == other.taskId;

  @override
  int get hashCode => Object.hash(
    nodeId,
    conversationId,
    Object.hashAll(messages),
    waiting,
    step,
    taskId,
  );
}
