part of '../project_radar.dart';

/// Arma el estado del proyecto cruzando repo, base local y sesiones vivas.
///
/// [roadmap] sale de leer la carpeta (sin caché, a propósito), [claims] de la
/// base, y las sesiones del propio proyecto. [now] entra por parámetro para
/// que la función no dependa del reloj y se pueda probar.
ProjectRadar buildProjectRadar({
  required Project project,
  required List<RoadmapTask> roadmap,
  required List<TaskClaim> claims,
  required int totalSteps,
  required DateTime now,
  bool hasRoadmap = true,
}) {
  final live = {
    for (final claim in claims)
      if (!claim.isExpiredAt(now)) claim.taskPath: claim,
  };
  final sessionsById = {
    for (final session in project.sessions) session.id: session,
  };

  var done = 0, running = 0, blocked = 0, free = 0, drafts = 0;
  final stuck = <RadarStuck>[];

  for (final task in roadmap) {
    if (task.isDraft) {
      drafts++;
      continue;
    }
    switch (_bucketOf(task, claimed: live.containsKey(task.path))) {
      case RadarBucket.done:
        done++;
      case RadarBucket.running:
        running++;
      case RadarBucket.blocked:
        blocked++;
      case RadarBucket.free:
        free++;
    }

    if (task.state == RoadmapState.hecho) continue;
    for (final blocker in task.blockers) {
      if (blocker.isBroken) {
        stuck.add(
          RadarStuck(
            taskPath: task.path,
            kind: blocker.target == BlockerTarget.missing
                ? StuckKind.missing
                : StuckKind.ambiguous,
            reference: blocker.reference,
            detail: blocker.target == BlockerTarget.missing
                ? 'no existe: alguien renumeró y no arrastró la referencia'
                : 'existe en dos carpetas: escribí la ruta completa',
          ),
        );
      } else if (!blocker.resolved) {
        stuck.add(
          RadarStuck(
            taskPath: task.path,
            kind: StuckKind.blocker,
            reference: blocker.reference,
            detail: blocker.reason,
          ),
        );
      }
    }
  }

  // Las tomas se muestran ordenadas por la que se venció antes: lo que está
  // por caerse va arriba, que es lo único accionable de esta lista.
  final inProgress =
      live.values
          .map(
            (claim) => RadarWorkItem(
              taskPath: claim.taskPath,
              title: claim.title,
              profileHandle: claim.profileHandle,
              sessionId: claim.sessionId,
              sessionTitle: claim.sessionTitle.isEmpty
                  ? sessionsById[claim.sessionId]?.title ?? ''
                  : claim.sessionTitle,
              claimedAt: claim.claimedAt,
              expiresAt: claim.expiresAt,
              live: sessionsById[claim.sessionId]?.isRunning ?? false,
            ),
          )
          .toList()
        ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));

  final claimedBySession = {
    for (final claim in live.values) claim.sessionId: claim.taskPath,
  };

  return ProjectRadar(
    hasRoadmap: hasRoadmap,
    done: done,
    running: running,
    blocked: blocked,
    free: free,
    drafts: drafts,
    inProgress: inProgress,
    sessions: [
      for (final session in project.sessions)
        RadarSession(
          id: session.id,
          title: session.title,
          status: session.status,
          stepIndex: session.currentStepIndex,
          totalSteps: totalSteps,
          planDone: session.plan.doneCount,
          planTotal: session.plan.length,
          costUsd: session.costUsd,
          isRunning: session.isRunning,
          claimedTaskPath: claimedBySession[session.id],
        ),
    ],
    stuck: stuck,
  );
}

/// La toma manda sobre el archivo: `estado: libre` con alguien trabajándola es
/// "en curso". El `.md` se marca al cerrar el turno, así que hasta entonces
/// diría que nadie la está haciendo justo cuando alguien la está haciendo.
RadarBucket _bucketOf(RoadmapTask task, {required bool claimed}) {
  if (task.state == RoadmapState.hecho) return RadarBucket.done;
  if (task.hasOpenBlockers ||
      task.brokenBlockers.isNotEmpty ||
      task.state == RoadmapState.bloqueado) {
    return RadarBucket.blocked;
  }
  if (claimed || task.state == RoadmapState.enCurso) return RadarBucket.running;
  return RadarBucket.free;
}
