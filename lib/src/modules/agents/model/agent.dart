import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'package:keel_ui/src/modules/agents/model/agent_icon_colors.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/modules/agents/model/agent_tool_activity.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/model/effort_level.dart';
import 'package:keel_ui/src/modules/agents/model/file_edit.dart';
import 'package:keel_ui/src/modules/agents/model/permission_request.dart';
import 'package:keel_ui/src/modules/agents/model/queued_message.dart';

class Agent {
  final String id;
  final String name;
  final String model;
  final AgentProvider provider;
  final DateTime createdAt;
  final String? sessionId;
  final List<ChatMessage> messages;
  final bool isStreaming;
  final bool fullFileSystemAccess;
  final Color iconColor;
  final String effort;
  final AgentToolActivity? currentActivity;
  final PermissionRequest? pendingPermission;
  final String? liveReasoning;
  final int? contextUsedTokens;
  final int? contextWindowTokens;
  final FileEdit? pendingUserEdit;
  final String? profileId;

  /// What the user typed while this agent was streaming, waiting to go out
  /// as the next turn. Transient like [isStreaming] and never serialized: a
  /// queue is only meaningful next to the turn it was typed during, and a
  /// message resurrected three launches later would be sent into a
  /// conversation that has moved on.
  final List<QueuedMessage> queuedMessages;

  const Agent({
    required this.id,
    required this.name,
    required this.model,
    required this.createdAt,
    required this.iconColor,
    required this.effort,
    this.provider = AgentProvider.claude,
    this.sessionId,
    this.messages = const [],
    this.isStreaming = false,
    this.fullFileSystemAccess = false,
    this.currentActivity,
    this.pendingPermission,
    this.liveReasoning,
    this.contextUsedTokens,
    this.contextWindowTokens,
    this.pendingUserEdit,
    this.profileId,
    this.queuedMessages = const [],
  });

  double? get contextUsageRatio {
    final used = contextUsedTokens;
    final window = contextWindowTokens;
    if (used == null || window == null || window <= 0) return null;
    return (used / window).clamp(0.0, 1.0);
  }

  Agent copyWith({
    String? model,
    String? sessionId,
    List<ChatMessage>? messages,
    bool? isStreaming,
    bool? fullFileSystemAccess,
    Color? iconColor,
    String? effort,
    AgentToolActivity? currentActivity,
    bool clearCurrentActivity = false,
    PermissionRequest? pendingPermission,
    bool clearPendingPermission = false,
    String? liveReasoning,
    bool clearLiveReasoning = false,
    int? contextUsedTokens,
    int? contextWindowTokens,
    FileEdit? pendingUserEdit,
    bool clearPendingUserEdit = false,
    String? profileId,
    List<QueuedMessage>? queuedMessages,
  }) {
    return Agent(
      id: id,
      name: name,
      model: model ?? this.model,
      provider: provider,
      createdAt: createdAt,
      sessionId: sessionId ?? this.sessionId,
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      fullFileSystemAccess: fullFileSystemAccess ?? this.fullFileSystemAccess,
      iconColor: iconColor ?? this.iconColor,
      effort: effort ?? this.effort,
      currentActivity: clearCurrentActivity
          ? null
          : (currentActivity ?? this.currentActivity),
      pendingPermission: clearPendingPermission
          ? null
          : (pendingPermission ?? this.pendingPermission),
      liveReasoning: clearLiveReasoning
          ? null
          : (liveReasoning ?? this.liveReasoning),
      contextUsedTokens: contextUsedTokens ?? this.contextUsedTokens,
      contextWindowTokens: contextWindowTokens ?? this.contextWindowTokens,
      pendingUserEdit: clearPendingUserEdit
          ? null
          : (pendingUserEdit ?? this.pendingUserEdit),
      profileId: profileId ?? this.profileId,
      queuedMessages: queuedMessages ?? this.queuedMessages,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'model': model,
    'provider': provider.alias,
    'createdAt': createdAt.toIso8601String(),
    'sessionId': sessionId,
    'messages': messages.map((message) => message.toJson()).toList(),
    'fullFileSystemAccess': fullFileSystemAccess,
    'iconColor': iconColor.toARGB32(),
    'effort': effort,
    'contextUsedTokens': contextUsedTokens,
    'contextWindowTokens': contextWindowTokens,
    'profileId': profileId,
  };

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      id: json['id'] as String,
      name: json['name'] as String,
      model: json['model'] as String,
      provider: json['provider'] == null
          ? AgentProvider.claude
          : AgentProvider.fromAlias(json['provider'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      sessionId: json['sessionId'] as String?,
      messages: (json['messages'] as List)
          .map((entry) => ChatMessage.fromJson(entry as Map<String, dynamic>))
          .toList(),
      fullFileSystemAccess: json['fullFileSystemAccess'] as bool? ?? false,
      iconColor: json['iconColor'] == null
          ? kAgentIconColorPalette.first
          : Color(json['iconColor'] as int),
      effort: json['effort'] as String? ?? kDefaultEffortAlias,
      contextUsedTokens: json['contextUsedTokens'] as int?,
      contextWindowTokens: json['contextWindowTokens'] as int?,
      profileId: json['profileId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Agent &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          model == other.model &&
          provider == other.provider &&
          createdAt == other.createdAt &&
          sessionId == other.sessionId &&
          listEquals(messages, other.messages) &&
          isStreaming == other.isStreaming &&
          fullFileSystemAccess == other.fullFileSystemAccess &&
          iconColor == other.iconColor &&
          effort == other.effort &&
          currentActivity == other.currentActivity &&
          pendingPermission == other.pendingPermission &&
          liveReasoning == other.liveReasoning &&
          contextUsedTokens == other.contextUsedTokens &&
          contextWindowTokens == other.contextWindowTokens &&
          pendingUserEdit == other.pendingUserEdit &&
          profileId == other.profileId &&
          listEquals(queuedMessages, other.queuedMessages);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    model,
    provider,
    createdAt,
    sessionId,
    Object.hashAll(messages),
    isStreaming,
    fullFileSystemAccess,
    iconColor,
    effort,
    currentActivity,
    pendingPermission,
    liveReasoning,
    Object.hash(contextUsedTokens, contextWindowTokens),
    pendingUserEdit,
    profileId,
    Object.hashAll(queuedMessages),
  );

  @override
  String toString() =>
      'Agent(id: $id, name: $name, model: $model, '
      'provider: ${provider.alias}, createdAt: $createdAt, '
      'sessionId: $sessionId, messages: ${messages.length}, isStreaming: $isStreaming, '
      'fullFileSystemAccess: $fullFileSystemAccess, iconColor: $iconColor, '
      'effort: $effort, currentActivity: $currentActivity, '
      'pendingPermission: $pendingPermission, liveReasoning: $liveReasoning, '
      'contextUsedTokens: $contextUsedTokens, contextWindowTokens: $contextWindowTokens, '
      'pendingUserEdit: $pendingUserEdit, profileId: $profileId, '
      'queued: ${queuedMessages.length})';
}

class AgentsState {
  final List<Agent> agents;
  final String? selectedAgentId;

  const AgentsState({this.agents = const [], this.selectedAgentId});

  Agent? get selectedAgent {
    final id = selectedAgentId;
    if (id == null) return null;
    for (final agent in agents) {
      if (agent.id == id) return agent;
    }
    return null;
  }

  AgentsState copyWith({List<Agent>? agents, String? selectedAgentId}) {
    return AgentsState(
      agents: agents ?? this.agents,
      selectedAgentId: selectedAgentId ?? this.selectedAgentId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentsState &&
          runtimeType == other.runtimeType &&
          listEquals(agents, other.agents) &&
          selectedAgentId == other.selectedAgentId;

  @override
  int get hashCode => Object.hash(Object.hashAll(agents), selectedAgentId);

  @override
  String toString() =>
      'AgentsState(agents: ${agents.length}, selectedAgentId: $selectedAgentId)';
}
