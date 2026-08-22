part of '../project_radar.dart';

/// En qué cajón cae una tarea del roadmap para el conteo.
///
/// La toma manda sobre el archivo: `estado: libre` con alguien trabajándola
/// es "en curso", porque el `.md` se marca al final del turno y hasta
/// entonces mentiría.
enum RadarBucket { done, running, blocked, free }

/// Por qué una tarea no se puede tomar.
enum StuckKind {
  /// Tiene un bloqueante sin cerrar que apunta a algo que sí existe.
  blocker,

  /// Apunta a una tarea que no existe: alguien renumeró y no arrastró.
  missing,

  /// El nombre suelto coincide con dos tareas y no se puede elegir por él.
  ambiguous,
}

/// Una tarea que alguien está haciendo AHORA.
class RadarWorkItem {
  const RadarWorkItem({
    required this.taskPath,
    required this.title,
    required this.profileHandle,
    required this.sessionId,
    required this.sessionTitle,
    required this.claimedAt,
    required this.expiresAt,
    required this.live,
  });

  final String taskPath;
  final String title;
  final String profileHandle;
  final String sessionId;
  final String sessionTitle;
  final DateTime claimedAt;
  final DateTime expiresAt;

  /// La sesión tiene un turno corriendo ahora mismo.
  final bool live;

  Duration heldFor(DateTime now) => now.difference(claimedAt);
  Duration expiresIn(DateTime now) => expiresAt.difference(now);
}

/// Una sesión del proyecto, en el radar.
class RadarSession {
  const RadarSession({
    required this.id,
    required this.title,
    required this.status,
    required this.stepIndex,
    required this.totalSteps,
    required this.planDone,
    required this.planTotal,
    required this.costUsd,
    required this.isRunning,
    this.claimedTaskPath,
  });

  final String id;
  final String title;
  final SessionStatus status;
  final int stepIndex;
  final int totalSteps;
  final int planDone;
  final int planTotal;
  final double costUsd;
  final bool isRunning;

  /// Qué tarea del roadmap tiene tomada, si tiene alguna.
  final String? claimedTaskPath;
}

/// Uno de los motivos por los que una tarea está trabada.
class RadarBlockerIssue {
  const RadarBlockerIssue({
    required this.kind,
    required this.reference,
    required this.detail,
  });

  final StuckKind kind;

  /// A qué apunta el bloqueante.
  final String reference;

  /// La razón escrita en la tarea, o la explicación de por qué está rota.
  final String detail;
}

/// Una tarea trabada, con TODOS sus motivos juntos.
///
/// Agrupada por tarea a propósito: una fila por bloqueante repetía el mismo
/// archivo dos y tres veces seguidas, y lo que uno quiere saber primero es
/// cuántas tareas están trabadas, no cuántos motivos hay.
class RadarStuck {
  const RadarStuck({required this.taskPath, required this.issues});

  final String taskPath;
  final List<RadarBlockerIssue> issues;

  /// Lo peor que le pasa: una referencia rota manda sobre un bloqueante
  /// abierto, porque la primera nadie la puede destrabar trabajando.
  StuckKind get worst => issues.any((issue) => issue.kind != StuckKind.blocker)
      ? issues.firstWhere((issue) => issue.kind != StuckKind.blocker).kind
      : StuckKind.blocker;
}

/// Todo lo que la pantalla de Estado necesita saber.
class ProjectRadar {
  const ProjectRadar({
    required this.hasRoadmap,
    required this.done,
    required this.running,
    required this.blocked,
    required this.free,
    required this.drafts,
    required this.inProgress,
    required this.sessions,
    required this.stuck,
  });

  /// El proyecto tiene una carpeta de tareas legible. En false los conteos
  /// son todos cero y la pantalla muestra otra cosa: un cero no explica nada.
  final bool hasRoadmap;

  final int done;
  final int running;
  final int blocked;
  final int free;

  /// Los borradores se cuentan aparte y NO entran en el total: todavía no son
  /// una promesa, y meterlos hunde el porcentaje sin que nadie haya fallado.
  final int drafts;

  final List<RadarWorkItem> inProgress;
  final List<RadarSession> sessions;
  final List<RadarStuck> stuck;

  int get total => done + running + blocked + free;

  /// 0..1. Sin tareas es 0 y no una división por cero disfrazada de 100%.
  double get completion => total == 0 ? 0 : done / total;

  int get completionPercent => (completion * 100).round();
}
