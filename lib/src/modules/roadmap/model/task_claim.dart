import 'package:flutter/foundation.dart';

/// Cuánto dura una toma sin renovar.
///
/// Vence a propósito: si un agente se cae con la tarea tomada, sin
/// vencimiento esa tarea queda trabada para siempre y nadie sabe por qué.
/// Media hora alcanza para un turno largo y es corto para destrabar.
const kClaimTtl = Duration(minutes: 30);

/// Una tarea del roadmap tomada por alguien, ahora.
///
/// Es lo ÚNICO del sistema de tareas que no vive en el repo. El resto —la
/// definición, los bloqueantes, si está hecha— es propiedad del código y se
/// ramifica con él; esto es propiedad del momento, y por eso vive en la base
/// local y no se respalda: restaurarlo en otra máquina reviviría candados de
/// tareas que nadie está haciendo.
class TaskClaim {
  /// Raíz del proyecto: el directorio de trabajo del proyecto.
  ///
  /// Es lo que impide que dos proyectos con una tarea llamada igual se pisen.
  /// No lo manda el modelo: sale de la URL con la que se le entregó el
  /// servidor MCP a ese turno.
  final String projectPath;

  /// Nombre legible del proyecto, para mostrarlo sin una ruta larga.
  final String projectName;

  /// Ruta de la tarea relativa a la raíz del roadmap, con carpeta incluida:
  /// `01-fundacion/02-shell.md`.
  final String taskPath;

  /// El título que declara el propio archivo de la tarea.
  final String title;

  /// Quién la tomó: el handle del perfil que corre el turno.
  final String profileHandle;

  /// Y DÓNDE la está haciendo: la sesión del proyecto en la que corre ese
  /// turno. Sin esto, el estado del proyecto puede decir qué se está
  /// trabajando y con qué agente, pero no en cuál de sus sesiones — que es
  /// justo el hilo del que tirás cuando querés mirar.
  final String sessionId;
  final String sessionTitle;

  final DateTime claimedAt;
  final DateTime expiresAt;

  const TaskClaim({
    required this.projectPath,
    required this.projectName,
    required this.taskPath,
    required this.title,
    required this.profileHandle,
    required this.sessionId,
    required this.sessionTitle,
    required this.claimedAt,
    required this.expiresAt,
  });

  /// La carpeta del grupo: `01-fundacion`.
  String get folder {
    final cut = taskPath.lastIndexOf('/');
    return cut == -1 ? '' : taskPath.substring(0, cut);
  }

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  TaskClaim renewedAt(DateTime now) => TaskClaim(
    projectPath: projectPath,
    projectName: projectName,
    taskPath: taskPath,
    title: title,
    profileHandle: profileHandle,
    sessionId: sessionId,
    sessionTitle: sessionTitle,
    claimedAt: claimedAt,
    expiresAt: now.add(kClaimTtl),
  );

  /// La identidad de una toma: proyecto + tarea.
  ///
  /// Lleva la ruta del proyecto adentro justamente para que `02-shell.md` de
  /// un repo y `02-shell.md` de otro NO sean la misma cosa.
  String get id => claimIdFor(projectPath, taskPath);

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectPath': projectPath,
    'projectName': projectName,
    'taskPath': taskPath,
    'title': title,
    'profileHandle': profileHandle,
    'sessionId': sessionId,
    'sessionTitle': sessionTitle,
    'claimedAt': claimedAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
  };

  factory TaskClaim.fromJson(Map<String, dynamic> json) {
    return TaskClaim(
      projectPath: json['projectPath'] as String? ?? '',
      projectName: json['projectName'] as String? ?? '',
      taskPath: json['taskPath'] as String? ?? '',
      title: json['title'] as String? ?? '',
      profileHandle: json['profileHandle'] as String? ?? '',
      sessionId: json['sessionId'] as String? ?? '',
      sessionTitle: json['sessionTitle'] as String? ?? '',
      claimedAt: DateTime.parse(json['claimedAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskClaim &&
          runtimeType == other.runtimeType &&
          projectPath == other.projectPath &&
          taskPath == other.taskPath &&
          profileHandle == other.profileHandle &&
          sessionId == other.sessionId &&
          sessionTitle == other.sessionTitle &&
          claimedAt == other.claimedAt &&
          expiresAt == other.expiresAt;

  @override
  int get hashCode =>
      Object.hash(projectPath, taskPath, profileHandle, claimedAt, expiresAt);

  @override
  String toString() => 'TaskClaim($projectName/$taskPath por $profileHandle)';
}

/// La clave con la que se guarda una toma.
///
/// Determinista y con el proyecto adentro: dos repos distintos con la misma
/// tarea dan claves distintas, y el mismo par siempre da la misma clave —
/// que es lo que hace que "tomar" pueda ser una escritura que falla si ya
/// existe.
String claimIdFor(String projectPath, String taskPath) {
  final root = projectPath.endsWith('/')
      ? projectPath.substring(0, projectPath.length - 1)
      : projectPath;
  return '$root|$taskPath'.replaceAll(RegExp(r'[^A-Za-z0-9|._-]'), '_');
}

class RoadmapClaimsState {
  final List<TaskClaim> claims;

  const RoadmapClaimsState({this.claims = const []});

  RoadmapClaimsState copyWith({List<TaskClaim>? claims}) =>
      RoadmapClaimsState(claims: claims ?? this.claims);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoadmapClaimsState &&
          runtimeType == other.runtimeType &&
          listEquals(claims, other.claims);

  @override
  int get hashCode => Object.hashAll(claims);

  @override
  String toString() => 'RoadmapClaimsState(claims: ${claims.length})';
}
