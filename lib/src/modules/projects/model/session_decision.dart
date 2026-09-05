import 'package:flutter/foundation.dart';

/// Qué le está pidiendo un agente al usuario.
enum SessionDecisionKind {
  /// Un dato o una decisión de producto: «¿main o develop?».
  question,

  /// Un permiso que le falta para seguir (una tool, una carpeta).
  permission,

  /// La aprobación de un paso que la capacidad declara como aprobable
  /// (`approvalRequired`), antes de correrlo.
  approval,
}

enum SessionDecisionStatus { pending, answered, granted, denied, cancelled }

/// Lo único que espera del usuario: una pregunta, un permiso o una
/// aprobación, en UNA cola por sesión.
///
/// Antes había tres cosas distintas para «te está esperando»: una tarjeta de
/// permiso que aparecía después de que el CLI ya había denegado, un banner
/// de plan que saltaba aunque el agente solo hubiera preguntado, y ninguna
/// forma de saber que un nodo se paró por una pregunta. Esto las unifica y
/// se persiste: una decisión que no contestaste antes de cerrar la app sigue
/// ahí al volver.
@immutable
class SessionDecision {
  final String id;
  final SessionDecisionKind kind;
  final String profileId;
  final String workNodeId;
  final String title;
  final String detail;
  final List<String> options;

  /// Solo para [SessionDecisionKind.permission]: qué tool y con qué entrada.
  final String toolName;
  final String toolInput;

  /// Alcance con el que se concedió un permiso: once | session | profile |
  /// app. Lo consume la fase de permisos bloqueantes.
  final String scope;

  /// Hay un turno VIVO suspendido esperando esto (gate o `ask_user`). Muere
  /// con la app: al reabrir se cancela, porque el proceso que esperaba ya
  /// no existe. Una decisión no bloqueante (el nodo cerró con `needs_user`)
  /// sobrevive: el nodo está pausado en disco y sigue esperando.
  final bool blocking;
  final SessionDecisionStatus status;
  final String answer;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const SessionDecision({
    required this.id,
    required this.kind,
    required this.profileId,
    required this.workNodeId,
    required this.title,
    required this.createdAt,
    this.detail = '',
    this.options = const [],
    this.toolName = '',
    this.toolInput = '',
    this.scope = 'once',
    this.blocking = false,
    this.status = SessionDecisionStatus.pending,
    this.answer = '',
    this.resolvedAt,
  });

  bool get isPending => status == SessionDecisionStatus.pending;

  SessionDecision copyWith({
    SessionDecisionStatus? status,
    String? answer,
    String? scope,
    DateTime? resolvedAt,
  }) => SessionDecision(
    id: id,
    kind: kind,
    profileId: profileId,
    workNodeId: workNodeId,
    title: title,
    detail: detail,
    options: options,
    toolName: toolName,
    toolInput: toolInput,
    scope: scope ?? this.scope,
    blocking: blocking,
    status: status ?? this.status,
    answer: answer ?? this.answer,
    createdAt: createdAt,
    resolvedAt: resolvedAt ?? this.resolvedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'profileId': profileId,
    'workNodeId': workNodeId,
    'title': title,
    'detail': detail,
    'options': options,
    'toolName': toolName,
    'toolInput': toolInput,
    'scope': scope,
    'blocking': blocking,
    'status': status.name,
    'answer': answer,
    'createdAt': createdAt.toIso8601String(),
    'resolvedAt': resolvedAt?.toIso8601String(),
  };

  factory SessionDecision.fromJson(Map<String, dynamic> json) =>
      SessionDecision(
        id: json['id'] as String,
        kind: SessionDecisionKind.values.byName(
          json['kind'] as String? ?? SessionDecisionKind.question.name,
        ),
        profileId: json['profileId'] as String? ?? '',
        workNodeId: json['workNodeId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        detail: json['detail'] as String? ?? '',
        options: (json['options'] as List?)?.cast<String>() ?? const [],
        toolName: json['toolName'] as String? ?? '',
        toolInput: json['toolInput'] as String? ?? '',
        scope: json['scope'] as String? ?? 'once',
        blocking: json['blocking'] as bool? ?? false,
        status: SessionDecisionStatus.values.byName(
          json['status'] as String? ?? SessionDecisionStatus.pending.name,
        ),
        answer: json['answer'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        resolvedAt: json['resolvedAt'] == null
            ? null
            : DateTime.parse(json['resolvedAt'] as String),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionDecision &&
          id == other.id &&
          kind == other.kind &&
          profileId == other.profileId &&
          workNodeId == other.workNodeId &&
          title == other.title &&
          detail == other.detail &&
          listEquals(options, other.options) &&
          toolName == other.toolName &&
          toolInput == other.toolInput &&
          scope == other.scope &&
          blocking == other.blocking &&
          status == other.status &&
          answer == other.answer &&
          createdAt == other.createdAt &&
          resolvedAt == other.resolvedAt;

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    profileId,
    workNodeId,
    title,
    detail,
    Object.hashAll(options),
    toolName,
    toolInput,
    scope,
    blocking,
    status,
    answer,
    createdAt,
    resolvedAt,
  );
}
