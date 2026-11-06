import 'package:flutter/material.dart';

import 'package:keel_core/modules/catalog_locks/model/catalog_lock.dart';
import 'package:keel_ui/src/modules/catalog_locks/ui/widget/catalog_lock_button.dart';
import 'package:keel_ui/src/modules/catalog_locks/viewmodel/catalog_locks_viewmodel.dart';
import 'package:keel_core/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/workspace/viewmodel/workspace_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/ui/screen/project_form_screen.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/project_delete_dialog.dart';

class ProjectTile extends StatelessWidget {
  const ProjectTile({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final isLocked = CatalogLocksService.instance.notifier.isLocked(
      CatalogLockKind.project,
      project.name,
    );
    return ListTile(
      title: Text(
        '#${project.name}',
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontFamily: 'monospace'),
      ),
      isThreeLine: true,
      onTap: () => WorkspaceService.instance.notifier.openProject(project.id),
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
          CatalogLockButton(kind: CatalogLockKind.project, name: project.name),
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: isLocked
                ? null
                : () => openProjectFormScreen(context, initial: project),
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline),
            onPressed: isLocked
                ? null
                : () => confirmAndDeleteProject(context, project),
          ),
        ],
      ),
    );
  }
}
