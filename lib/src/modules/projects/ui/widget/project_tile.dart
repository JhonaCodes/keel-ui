import 'package:flutter/material.dart';

import 'package:keel_ui/src/core/ui/typed_deletion_dialog.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/requirements/viewmodel/requirements_viewmodel.dart';
import 'package:keel_ui/src/modules/roadmap/viewmodel/task_claims_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/ui/screen/project_form_screen.dart';

class ProjectTile extends StatelessWidget {
  const ProjectTile({super.key, required this.project});

  final Project project;

  Future<void> _confirmAndDelete(BuildContext context) async {
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

    final confirmed = await confirmTypedDeletion(
      context,
      title: 'Eliminar el proyecto #${project.name}',
      expected: project.name,
      consequences: [
        (
          lead:
              '${project.sessions.length} ${_plural(project.sessions.length, 'sesión', 'sesiones')}',
          rest: 'con sus hilos y su contexto',
        ),
        (
          lead: '$messages ${_plural(messages, 'mensaje', 'mensajes')}',
          rest: '',
        ),
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
  }

  static String _plural(int n, String one, String many) => n == 1 ? one : many;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        '#${project.name}',
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontFamily: 'monospace'),
      ),
      isThreeLine: true,
      onTap: () => ProjectsService.instance.notifier.selectProject(project.id),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (project.purpose.isNotEmpty) Text(project.purpose),
          Text(
            '${project.profileIds.length} agente(s) · '
            '${project.workflowIds.length} workflow(s) · '
            '${project.sessions.length} sesión(s)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => openProjectFormScreen(context, initial: project),
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmAndDelete(context),
          ),
        ],
      ),
    );
  }
}
