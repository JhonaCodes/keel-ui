import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'package:keel_ui/src/modules/agents/model/agent.dart';
import 'package:keel_ui/src/modules/agents/model/agent_icon_colors.dart';
import 'package:keel_ui/src/modules/agents/model/agent_tool_activity.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/model/permission_request.dart';
import 'package:keel_ui/src/modules/agents/model/queued_message.dart';

/// Wire model for the assistant window bridge: the full [Agent] state the
/// dedicated Keel AI window needs to render, TRANSIENTS INCLUDED — which is
/// exactly why this is not [Agent.toJson] (that's the persistence format and
/// deliberately omits streaming/activity/permission state).
///
/// `fileEdits` are stripped from every message on purpose: they're the one
/// unbounded field (full before/after file contents), and Keel AI acts
/// through its MCP tools, not through file edits, so the window loses
/// nothing by not rendering them.
class AssistantAgentSnapshot {
  final String id;
  final String name;
  final String model;
  final String effort;
  final bool fullFileSystemAccess;
  final bool isStreaming;
  final Color iconColor;
  final List<ChatMessage> messages;
  final String? liveReasoning;
  final AgentToolActivity? currentActivity;
  final PermissionRequest? pendingPermission;
  final int? contextUsedTokens;
  final int? contextWindowTokens;

  /// Typed during the current turn, waiting to go out as the next one — on
  /// the wire so the assistant window renders the same pending strip the
  /// main window does.
  final List<QueuedMessage> queuedMessages;

  const AssistantAgentSnapshot({
    required this.id,
    required this.name,
    required this.model,
    required this.effort,
    required this.fullFileSystemAccess,
    required this.isStreaming,
    required this.iconColor,
    required this.messages,
    this.liveReasoning,
    this.currentActivity,
    this.pendingPermission,
    this.contextUsedTokens,
    this.contextWindowTokens,
    this.queuedMessages = const [],
  });

  factory AssistantAgentSnapshot.fromAgent(Agent agent) {
    return AssistantAgentSnapshot(
      id: agent.id,
      name: agent.name,
      model: agent.model,
      effort: agent.effort,
      fullFileSystemAccess: agent.fullFileSystemAccess,
      isStreaming: agent.isStreaming,
      iconColor: agent.iconColor,
      messages: [
        for (final message in agent.messages)
          message.fileEdits.isEmpty ? message : _withoutFileEdits(message),
      ],
      liveReasoning: agent.liveReasoning,
      currentActivity: agent.currentActivity,
      pendingPermission: agent.pendingPermission,
      contextUsedTokens: agent.contextUsedTokens,
      contextWindowTokens: agent.contextWindowTokens,
      queuedMessages: agent.queuedMessages,
    );
  }

  /// Rebuilds a renderable [Agent] for [ChatView] in the window's engine.
  /// `createdAt` is not on the wire (nothing in the chat renders it), so the
  /// receiving side stamps a fixed epoch — this Agent never persists.
  Agent toAgent() {
    return Agent(
      id: id,
      name: name,
      model: model,
      createdAt: DateTime.fromMicrosecondsSinceEpoch(0),
      iconColor: iconColor,
      effort: effort,
      messages: messages,
      isStreaming: isStreaming,
      fullFileSystemAccess: fullFileSystemAccess,
      currentActivity: currentActivity,
      pendingPermission: pendingPermission,
      liveReasoning: liveReasoning,
      contextUsedTokens: contextUsedTokens,
      contextWindowTokens: contextWindowTokens,
      queuedMessages: queuedMessages,
    );
  }

  static ChatMessage _withoutFileEdits(ChatMessage message) {
    return ChatMessage(
      role: message.role,
      text: message.text,
      timestamp: message.timestamp,
      costUsd: message.costUsd,
      durationMs: message.durationMs,
      reasoning: message.reasoning,
      authorProfileId: message.authorProfileId,
      stepIndex: message.stepIndex,
      consultOfProfileId: message.consultOfProfileId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'model': model,
    'effort': effort,
    'fullFileSystemAccess': fullFileSystemAccess,
    'isStreaming': isStreaming,
    'iconColor': iconColor.toARGB32(),
    'messages': messages.map((message) => message.toJson()).toList(),
    'liveReasoning': liveReasoning,
    'currentActivity': currentActivity?.toJson(),
    'pendingPermission': pendingPermission?.toJson(),
    'contextUsedTokens': contextUsedTokens,
    'contextWindowTokens': contextWindowTokens,
    'queuedMessages': queuedMessages.map((entry) => entry.toJson()).toList(),
  };

  factory AssistantAgentSnapshot.fromJson(Map<String, dynamic> json) {
    return AssistantAgentSnapshot(
      id: json['id'] as String,
      name: json['name'] as String,
      model: json['model'] as String,
      effort: json['effort'] as String,
      fullFileSystemAccess: json['fullFileSystemAccess'] as bool,
      isStreaming: json['isStreaming'] as bool,
      iconColor: json['iconColor'] == null
          ? kAgentIconColorPalette.first
          : Color(json['iconColor'] as int),
      messages: (json['messages'] as List)
          .map((entry) => ChatMessage.fromJson(entry as Map<String, dynamic>))
          .toList(),
      liveReasoning: json['liveReasoning'] as String?,
      currentActivity: json['currentActivity'] == null
          ? null
          : AgentToolActivity.fromJson(
              json['currentActivity'] as Map<String, dynamic>,
            ),
      pendingPermission: json['pendingPermission'] == null
          ? null
          : PermissionRequest.fromJson(
              json['pendingPermission'] as Map<String, dynamic>,
            ),
      contextUsedTokens: json['contextUsedTokens'] as int?,
      contextWindowTokens: json['contextWindowTokens'] as int?,
      queuedMessages:
          (json['queuedMessages'] as List?)
              ?.map(
                (entry) =>
                    QueuedMessage.fromJson(entry as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssistantAgentSnapshot &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          model == other.model &&
          effort == other.effort &&
          fullFileSystemAccess == other.fullFileSystemAccess &&
          isStreaming == other.isStreaming &&
          iconColor == other.iconColor &&
          listEquals(messages, other.messages) &&
          liveReasoning == other.liveReasoning &&
          currentActivity == other.currentActivity &&
          pendingPermission == other.pendingPermission &&
          contextUsedTokens == other.contextUsedTokens &&
          contextWindowTokens == other.contextWindowTokens &&
          listEquals(queuedMessages, other.queuedMessages);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    model,
    effort,
    fullFileSystemAccess,
    isStreaming,
    iconColor,
    Object.hashAll(messages),
    liveReasoning,
    currentActivity,
    pendingPermission,
    contextUsedTokens,
    contextWindowTokens,
    Object.hashAll(queuedMessages),
  );

  @override
  String toString() =>
      'AssistantAgentSnapshot(id: $id, messages: ${messages.length}, '
      'isStreaming: $isStreaming)';
}

/// One row of the window's sessions menu: enough to pick a conversation
/// without shipping its messages.
class AssistantSessionSummary {
  final String id;
  final String label;

  const AssistantSessionSummary({required this.id, required this.label});

  /// Same preview the old side panel built: first user line + creation time.
  factory AssistantSessionSummary.fromAgent(Agent agent) {
    final time =
        '${agent.createdAt.hour.toString().padLeft(2, '0')}:'
        '${agent.createdAt.minute.toString().padLeft(2, '0')}';
    final firstUserMessage = agent.messages
        .where((message) => message.role == ChatRole.user)
        .firstOrNull;
    if (firstUserMessage == null) {
      return AssistantSessionSummary(id: agent.id, label: 'Nueva ($time)');
    }
    final firstLine = firstUserMessage.text.trim().split('\n').first;
    final preview = firstLine.length > 28
        ? '${firstLine.substring(0, 28)}…'
        : firstLine;
    return AssistantSessionSummary(id: agent.id, label: '$preview ($time)');
  }

  Map<String, dynamic> toJson() => {'id': id, 'label': label};

  factory AssistantSessionSummary.fromJson(Map<String, dynamic> json) {
    return AssistantSessionSummary(
      id: json['id'] as String,
      label: json['label'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssistantSessionSummary &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          label == other.label;

  @override
  int get hashCode => Object.hash(id, label);

  @override
  String toString() => 'AssistantSessionSummary(id: $id, label: $label)';
}

/// Everything the assistant window renders, in one idempotent snapshot.
/// [seq] is monotonic and emitted only by main: the window discards any
/// state whose seq is not newer than the last applied, which makes lost or
/// late pushes harmless (the next one repaints everything).
class AssistantWindowState {
  final int seq;
  final String? activeAgentId;
  final AssistantAgentSnapshot? agent;
  final List<AssistantSessionSummary> sessions;

  const AssistantWindowState({
    this.seq = 0,
    this.activeAgentId,
    this.agent,
    this.sessions = const [],
  });

  Map<String, dynamic> toJson() => {
    'seq': seq,
    'activeAgentId': activeAgentId,
    'agent': agent?.toJson(),
    'sessions': sessions.map((session) => session.toJson()).toList(),
  };

  factory AssistantWindowState.fromJson(Map<String, dynamic> json) {
    return AssistantWindowState(
      seq: json['seq'] as int,
      activeAgentId: json['activeAgentId'] as String?,
      agent: json['agent'] == null
          ? null
          : AssistantAgentSnapshot.fromJson(
              json['agent'] as Map<String, dynamic>,
            ),
      sessions: (json['sessions'] as List)
          .map(
            (entry) =>
                AssistantSessionSummary.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssistantWindowState &&
          runtimeType == other.runtimeType &&
          seq == other.seq &&
          activeAgentId == other.activeAgentId &&
          agent == other.agent &&
          listEquals(sessions, other.sessions);

  @override
  int get hashCode =>
      Object.hash(seq, activeAgentId, agent, Object.hashAll(sessions));

  @override
  String toString() =>
      'AssistantWindowState(seq: $seq, activeAgentId: $activeAgentId, '
      'sessions: ${sessions.length})';
}
