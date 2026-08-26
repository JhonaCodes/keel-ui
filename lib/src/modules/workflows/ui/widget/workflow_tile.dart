import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/catalog_locks/model/catalog_lock.dart';
import 'package:keel_ui/src/modules/catalog_locks/ui/widget/catalog_lock_button.dart';
import 'package:keel_ui/src/modules/catalog_locks/viewmodel/catalog_locks_viewmodel.dart';
import 'package:keel_ui/src/integrations/catalog_bundle/catalog_bundle.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/service/workflow_deletion_service.dart';
import 'package:keel_ui/src/modules/workflows/ui/screen/workflow_form_screen.dart';

class WorkflowTile extends StatelessWidget {
  const WorkflowTile({super.key, required this.workflow});

  final Workflow workflow;

  Future<void> _confirmAndDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar workflow'),
        content: Text(
          'Se eliminará el workflow "${workflow.name}" y se limpiarán sus '
          'asignaciones, default, overrides y referencias de sesión en todos '
          'los proyectos. El historial y los casos ya materializados se '
          'conservan.',
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
      workflowDeletionService.deleteWorkflow(workflow.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = CatalogLocksService.instance.notifier.isLocked(
      CatalogLockKind.workflow,
      workflow.name,
    );
    return ListTile(
      title: Text(workflow.name),
      isThreeLine: true,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (workflow.whenToApply.isNotEmpty) Text(workflow.whenToApply),
          Text(
            '${_kindLabel(workflow.kind)} · responsable '
            '${workflow.policy.resolutionRole.isEmpty ? 'cualquier miembro' : workflow.policy.resolutionRole}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (workflow.policy.requiredSkillNames.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final skill in workflow.policy.requiredSkillNames)
                    Chip(
                      label: Text(
                        skill,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CatalogLockButton(
            kind: CatalogLockKind.workflow,
            name: workflow.name,
          ),
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: isLocked
                ? null
                : () => openWorkflowFormScreen(context, initial: workflow),
          ),
          IconButton(
            tooltip: 'Exportar como paquete',
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: () => openBundleExportPanel(
              context,
              BundleKind.workflow,
              workflow.name,
            ),
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline),
            onPressed: isLocked ? null : () => _confirmAndDelete(context),
          ),
        ],
      ),
    );
  }
}

String _kindLabel(WorkflowKind kind) => switch (kind) {
  WorkflowKind.general => 'General',
  WorkflowKind.bug => 'Bug',
  WorkflowKind.migration => 'Migración',
  WorkflowKind.roadmap => 'Formato',
};
