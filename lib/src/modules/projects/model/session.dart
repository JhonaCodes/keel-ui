import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/model/permission_request.dart';
import 'package:keel_ui/src/modules/projects/model/session_plan_item.dart';
import 'package:keel_ui/src/modules/projects/model/session_live_turn.dart';
import 'package:keel_ui/src/modules/projects/model/session_subagent.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_case.dart';
import 'package:keel_ui/src/modules/projects/model/session_queued_message.dart';
import 'package:keel_ui/src/modules/projects/model/session_usage.dart';

enum SessionStatus { running, finished, failed }

/// Lo que queda escrito en [Session.workflowId] al leer una sesión guardada
/// cuando «ser la sesión de formato» todavía era un booleano.
///
/// Vive un solo arranque: `ProjectsViewModel` la cambia por el id del
/// workflow de formato al revivir los proyectos, y el guardado siguiente ya
/// escribe el id de verdad.
const kSessionFormatMigrationMark = 'migrar:formato';

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

  final bool isRunning;

  /// The adaptive case that owns work, findings, and validation. It replaces
  /// the positional workflow cursor; work advances by satisfied dependencies.
  final ResolutionCase? resolutionCase;

  /// Con qué workflow corre ESTA sesión.
  ///
  /// El workflow era del proyecto y ahora es de la sesión, que es donde
  /// siempre perteneció: un proyecto hace cosas de clases distintas —armar
  /// la carpeta de tareas, resolver un ticket, evaluar un requerimiento— y
  /// mandarlas a todas por la misma fila de agentes es la razón por la que
  /// formatear unos markdown terminaba abriendo un PR.
  ///
  /// Vacío solo mientras la sesión no arrancó y nadie eligió. Las sesiones
  /// guardadas antes de que esto existiera se migran al abrir la app.
  final String workflowId;

  /// Exact usage reported by the providers for this session. It survives the
  /// machine ledger's retention window and keeps independent totals per
  /// workflow node and profile.
  final SessionUsage usage;

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

  /// Mensajes escritos mientras otro turno todavía tenía el canal. Se guardan
  /// con la sesión para que cambiar de pantalla o reiniciar la app no los haga
  /// desaparecer.
  final List<SessionQueuedMessage> queuedMessages;

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
    this.workflowId = '',
    this.isRunning = false,
    this.resolutionCase,
    this.usage = const SessionUsage(),
    this.pendingPermission,
    this.liveTurn,
    this.subagents = const [],
    this.queuedMessages = const [],
  });

  /// How full the context is, 0..1, or null while nothing has reported yet.
  double? get contextUsageRatio {
    final used = usage.latestContextUsedTokens;
    final window = usage.latestContextWindowTokens;
    if (used <= 0 || window <= 0) return null;
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
    String? workflowId,
    bool? isRunning,
    ResolutionCase? resolutionCase,
    bool clearResolutionCase = false,
    SessionUsage? usage,
    PermissionRequest? pendingPermission,
    bool clearPendingPermission = false,
    SessionLiveTurn? liveTurn,
    bool clearLiveTurn = false,
    List<SessionSubagent>? subagents,
    List<SessionQueuedMessage>? queuedMessages,
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
      workflowId: workflowId ?? this.workflowId,
      isRunning: isRunning ?? this.isRunning,
      resolutionCase: clearResolutionCase
          ? null
          : (resolutionCase ?? this.resolutionCase),
      usage: usage ?? this.usage,
      pendingPermission: clearPendingPermission
          ? null
          : (pendingPermission ?? this.pendingPermission),
      liveTurn: clearLiveTurn ? null : (liveTurn ?? this.liveTurn),
      subagents: subagents ?? this.subagents,
      queuedMessages: queuedMessages ?? this.queuedMessages,
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
    'workflowId': workflowId,
    'isRunning': isRunning,
    'resolutionCase': resolutionCase?.toJson(),
    'usage': usage.toJson(),
    'subagents': [for (final subagent in subagents) subagent.toJson()],
    'queuedMessages': [for (final message in queuedMessages) message.toJson()],
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
      // Lo de antes era un booleano. Se traduce a una marca que `_revived`
      // cambia por el id del workflow de formato en el primer arranque, y
      // que desaparece en cuanto se guarda de nuevo.
      workflowId:
          json['workflowId'] as String? ??
          ((json['isFormatSession'] as bool? ?? false)
              ? kSessionFormatMigrationMark
              : ''),
      isRunning: json['isRunning'] as bool? ?? false,
      resolutionCase: json['resolutionCase'] is Map
          ? ResolutionCase.fromJson(
              (json['resolutionCase'] as Map).cast<String, dynamic>(),
            )
          : null,
      usage: _sessionUsageFrom(json),
      subagents: [
        for (final entry in json['subagents'] as List? ?? const [])
          SessionSubagent.fromJson(entry as Map<String, dynamic>),
      ],
      queuedMessages: [
        for (final entry in json['queuedMessages'] as List? ?? const [])
          SessionQueuedMessage.fromJson(entry as Map<String, dynamic>),
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
          workflowId == other.workflowId &&
          isRunning == other.isRunning &&
          usage == other.usage &&
          pendingPermission == other.pendingPermission &&
          liveTurn == other.liveTurn &&
          listEquals(subagents, other.subagents) &&
          listEquals(queuedMessages, other.queuedMessages);

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
    workflowId,
    isRunning,
    usage,
    pendingPermission,
    liveTurn,
    Object.hashAll(subagents),
    Object.hashAll(queuedMessages),
  );

  @override
  String toString() =>
      'Session(id: $id, title: $title, status: ${status.name}, '
      'messages: ${messages.length}, '
      'queued: ${queuedMessages.length}, '
      'running: $isRunning)';
}

SessionUsage _sessionUsageFrom(Map<String, dynamic> json) {
  final persisted = json['usage'];
  if (persisted is Map) {
    return SessionUsage.fromJson(persisted.cast<String, dynamic>());
  }

  // Old persisted sessions carried only cost and the latest context. Reading
  // those fields once preserves the evidence; the next save writes solely the
  // structured usage contract above.
  return SessionUsage(
    reportedCostUsd: (json['costUsd'] as num?)?.toDouble() ?? 0,
    latestContextUsedTokens: json['contextUsedTokens'] as int? ?? 0,
    latestContextWindowTokens: json['contextWindowTokens'] as int? ?? 0,
  );
}
