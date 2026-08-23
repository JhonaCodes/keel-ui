import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/model/permission_request.dart';
import 'package:keel_ui/src/modules/projects/model/session_plan_item.dart';
import 'package:keel_ui/src/modules/projects/model/session_live_turn.dart';
import 'package:keel_ui/src/modules/projects/model/session_subagent.dart';

enum SessionStatus { running, finished, failed }

SessionStatus _statusFromName(String? name) {
  return switch (name) {
    'finished' => SessionStatus.finished,
    'failed' => SessionStatus.failed,
    _ => SessionStatus.running,
  };
}

/// One run of a project's workflow: the visible thread plus the CLI sessions
/// it opened. Sessions live here, not on the project, so starting a new session
/// starts every member from a clean session and a clean screen — nothing is
/// carried over from the previous session.
class Session {
  final String id;
  final String title;
  final DateTime createdAt;
  final SessionStatus status;
  final List<ChatMessage> messages;
  final Map<String, String> cliSessionsByProfileId;

  /// Members added ONLY to this session ("traé un auditor para esta sesión").
  /// The project's own roster is untouched — other sessions never see them.
  final List<String> extraProfileIds;

  /// El plan de trabajo acordado en esta sesión: lo escribe el miembro que
  /// planifica y lo marcan los que lo cumplen. Vive acá y no en el hilo
  /// porque la pregunta "qué falta" tiene que tener una respuesta que no
  /// dependa de scrollear.
  final List<SessionPlanItem> plan;

  /// El pedido con el que arrancó la sesión, tal como lo escribió el usuario.
  /// Se guarda porque los ciclos 2..N corren con el punto del plan como
  /// pedido — sin esto, un miembro que entra recién en el ciclo 3 nunca ve
  /// qué se pidió en realidad.
  final String request;

  final int currentStepIndex;
  final bool isRunning;

  /// Si esta sesión existe para dejar la carpeta de tareas con el formato.
  ///
  /// Es una marca y no el título, porque el título se puede renombrar y lo
  /// que cuelga de esto no es cosmético: el skill del formato viaja en el
  /// turno, y al cerrar corre un chequeo que puede negarse a sellarla.
  final bool isFormatSession;

  /// Accumulated cost of every CLI turn this session ran (USD), total and
  /// broken down by member profile — the ledger that makes the economics of
  /// a channel visible instead of invisible.
  final double costUsd;
  final Map<String, double> costByProfileId;

  /// Context the last turn of this session reported. Per session, not per project:
  /// a new session opens fresh sessions, so its context starts from zero again.
  final int? contextUsedTokens;
  final int? contextWindowTokens;

  /// A tool one of the members tried to use and was not allowed to. Held on
  /// the session so the thread can ask you about it once, instead of the turn
  /// silently failing. Deliberately not persisted: a question you never
  /// answered is stale by the time the app reopens.
  final PermissionRequest? pendingPermission;

  /// The turn in flight: who holds it, what it is reasoning, which tool it has
  /// open. Not persisted — see [SessionLiveTurn].
  final SessionLiveTurn? liveTurn;

  /// Los subagentes que abrieron los miembros de esta sesión, en el orden en
  /// que arrancaron. A diferencia de [liveTurn] esto SÍ se guarda: lo que un
  /// subagente devolvió es historia del hilo, igual que un mensaje.
  final List<SessionSubagent> subagents;

  const Session({
    required this.id,
    required this.title,
    required this.createdAt,
    this.status = SessionStatus.running,
    this.messages = const [],
    this.cliSessionsByProfileId = const {},
    this.extraProfileIds = const [],
    this.plan = const [],
    this.request = '',
    this.isFormatSession = false,
    this.currentStepIndex = 0,
    this.isRunning = false,
    this.costUsd = 0,
    this.costByProfileId = const {},
    this.contextUsedTokens,
    this.contextWindowTokens,
    this.pendingPermission,
    this.liveTurn,
    this.subagents = const [],
  });

  /// How full the context is, 0..1, or null while nothing has reported yet.
  double? get contextUsageRatio {
    final used = contextUsedTokens;
    final window = contextWindowTokens;
    if (used == null || window == null || window <= 0) return null;
    return (used / window).clamp(0.0, 1.0);
  }

  Session copyWith({
    String? title,
    SessionStatus? status,
    List<ChatMessage>? messages,
    Map<String, String>? cliSessionsByProfileId,
    List<String>? extraProfileIds,
    List<SessionPlanItem>? plan,
    String? request,
    bool? isFormatSession,
    int? currentStepIndex,
    bool? isRunning,
    double? costUsd,
    Map<String, double>? costByProfileId,
    int? contextUsedTokens,
    int? contextWindowTokens,
    PermissionRequest? pendingPermission,
    bool clearPendingPermission = false,
    SessionLiveTurn? liveTurn,
    bool clearLiveTurn = false,
    List<SessionSubagent>? subagents,
  }) {
    return Session(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      status: status ?? this.status,
      messages: messages ?? this.messages,
      cliSessionsByProfileId:
          cliSessionsByProfileId ?? this.cliSessionsByProfileId,
      extraProfileIds: extraProfileIds ?? this.extraProfileIds,
      plan: plan ?? this.plan,
      request: request ?? this.request,
      isFormatSession: isFormatSession ?? this.isFormatSession,
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
      subagents: subagents ?? this.subagents,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'messages': messages.map((message) => message.toJson()).toList(),
    'sessionsByProfileId': cliSessionsByProfileId,
    'extraProfileIds': extraProfileIds,
    'plan': plan.map((item) => item.toJson()).toList(),
    'request': request,
    'isFormatSession': isFormatSession,
    'currentStepIndex': currentStepIndex,
    'isRunning': isRunning,
    'costUsd': costUsd,
    'costByProfileId': costByProfileId,
    'contextUsedTokens': contextUsedTokens,
    'contextWindowTokens': contextWindowTokens,
    'subagents': [for (final subagent in subagents) subagent.toJson()],
  };

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: _statusFromName(json['status'] as String?),
      messages: (json['messages'] as List? ?? const [])
          .map((entry) => ChatMessage.fromJson(entry as Map<String, dynamic>))
          .toList(),
      cliSessionsByProfileId:
          (json['sessionsByProfileId'] as Map?)?.cast<String, String>() ??
          const {},
      extraProfileIds:
          (json['extraProfileIds'] as List?)?.cast<String>() ?? const [],
      plan: (json['plan'] as List? ?? const [])
          .map(
            (entry) => SessionPlanItem.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
      request: json['request'] as String? ?? '',
      isFormatSession: json['isFormatSession'] as bool? ?? false,
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
      subagents: [
        for (final entry in json['subagents'] as List? ?? const [])
          SessionSubagent.fromJson(entry as Map<String, dynamic>),
      ],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Session &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          createdAt == other.createdAt &&
          status == other.status &&
          listEquals(messages, other.messages) &&
          mapEquals(cliSessionsByProfileId, other.cliSessionsByProfileId) &&
          listEquals(extraProfileIds, other.extraProfileIds) &&
          listEquals(plan, other.plan) &&
          request == other.request &&
          isFormatSession == other.isFormatSession &&
          currentStepIndex == other.currentStepIndex &&
          isRunning == other.isRunning &&
          costUsd == other.costUsd &&
          mapEquals(costByProfileId, other.costByProfileId) &&
          contextUsedTokens == other.contextUsedTokens &&
          contextWindowTokens == other.contextWindowTokens &&
          pendingPermission == other.pendingPermission &&
          liveTurn == other.liveTurn &&
          listEquals(subagents, other.subagents);

  @override
  int get hashCode => Object.hash(
    id,
    title,
    createdAt,
    status,
    Object.hashAll(messages),
    Object.hashAll(
      cliSessionsByProfileId.entries.map((e) => '${e.key}:${e.value}'),
    ),
    Object.hashAll(extraProfileIds),
    Object.hashAll(plan),
    request,
    isFormatSession,
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
    Object.hashAll(subagents),
  );

  @override
  String toString() =>
      'Session(id: $id, title: $title, status: ${status.name}, '
      'messages: ${messages.length}, step: $currentStepIndex, '
      'running: $isRunning)';
}
