import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/ui/screen/project_form_screen.dart';

class ProjectTile extends StatelessWidget {
  const ProjectTile({super.key, required this.project});

  final Project project;

  Future<void> _confirmAndDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar proyecto'),
        content: Text(
          'Se eliminará "#${project.name}" y todas sus sesiones. Esta acción '
          'no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      ProjectsService.instance.notifier.deleteProject(project.id);
    }
  }

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
