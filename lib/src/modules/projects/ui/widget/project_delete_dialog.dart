import 'package:flutter/material.dart';

import 'package:keel_core/modules/projects/model/project.dart';
import 'package:keel_ui/src/core/ui/confirm_card.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/requirements/viewmodel/requirements_viewmodel.dart';
import 'package:keel_ui/src/modules/roadmap/viewmodel/task_claims_viewmodel.dart';

/// Pregunta y, si se confirma, elimina [project]: con lo que se lleva
/// dicho antes de que se vaya. La usan la gestión de proyectos y el click
/// derecho de la barra. Devuelve si se eliminó.
Future<bool> confirmAndDeleteProject(
  BuildContext context,
  Project project,
) async {
  final messages = project.sessions.fold<int>(
    0,
    (total, session) => total + session.messages.length,
  );
  final claims = TaskClaimsService.instance.notifier
      .activeClaimsFor(project.workingDirectory)
      .length;
  final requirements = RequirementsService.instance.notifier;
  final abiertos = requirements.data.requirements
      .where(
        (requirement) =>
            requirement.status.isOpen &&
            (requirement.fromProjectId == project.id ||
                requirement.toProjectId == project.id),
      )
      .length;

  final confirmed = await confirmWithCard(
    context,
    title: 'Eliminar el proyecto #${project.name}',
    typeToConfirm: project.name,
    destructive: true,
    details: [
      (
        lead:
            '${project.sessions.length} ${_plural(project.sessions.length, 'sesión', 'sesiones')}',
        rest: 'con sus hilos y su contexto',
      ),
      (lead: '$messages ${_plural(messages, 'mensaje', 'mensajes')}', rest: ''),
      if (claims > 0)
        (
          lead: '$claims ${_plural(claims, 'toma', 'tomas')} de tareas',
          rest: 'del roadmap se liberan',
        ),
      if (abiertos > 0)
        (
          lead:
              '$abiertos ${_plural(abiertos, 'requerimiento abierto', 'requerimientos abiertos')}',
          rest:
              'quedan marcados «proyecto eliminado» — no se borran, el otro '
              'lado los necesita',
        ),
    ],
    reassurance: 'La carpeta del repo no se toca.',
  );

  if (confirmed) {
    ProjectsService.instance.notifier.deleteProject(project.id);
  }
  return confirmed;
}

String _plural(int n, String one, String many) => n == 1 ? one : many;
