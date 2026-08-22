import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';
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
          'Se eliminará el workflow "${workflow.name}". Los proyectos que lo '
          'tenían asignado dejarán de aplicarlo.',
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
      WorkflowsService.instance.notifier.deleteWorkflow(workflow.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = {
      for (final step in workflow.steps)
        if (step.role.isNotEmpty) step.role,
    }.toList();

    return ListTile(
      title: Text(workflow.name),
      isThreeLine: true,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (workflow.whenToApply.isNotEmpty) Text(workflow.whenToApply),
          Text(
            '${workflow.steps.length} paso(s)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (roles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final role in roles)
                    Chip(
                      label: Text(
                        role,
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
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => openWorkflowFormScreen(context, initial: workflow),
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
