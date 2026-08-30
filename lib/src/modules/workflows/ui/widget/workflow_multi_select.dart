import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/ui/screen/workflow_form_screen.dart';

/// Toggle-chip picker over the registered workflows catalog. Controlled
/// widget — [selectedNames] is the source of truth, [onChanged] reports
/// the next value.
class WorkflowMultiSelect extends StatelessWidget {
  const WorkflowMultiSelect({
    super.key,
    required this.selectedNames,
    required this.onChanged,
  });

  final List<String> selectedNames;
  final ValueChanged<List<String>> onChanged;

  void _toggle(String name, bool selected) {
    if (selected) {
      onChanged([...selectedNames, name]);
    } else {
      onChanged(selectedNames.where((entry) => entry != name).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              t.labelWorkflows,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => openWorkflowFormScreen(context),
              icon: const Icon(Icons.add, size: 18),
              label: Text(t.buttonRegister),
            ),
          ],
        ),
        ReactiveViewModelBuilder<WorkflowsViewModel, WorkflowsState>(
          viewmodel: WorkflowsService.instance.notifier,
          build: (state, viewmodel, keep) {
            if (state.workflows.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(t.messageNoWorkflowsRegistered),
              );
            }
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final workflow in state.workflows)
                  FilterChip(
                    avatar: const Icon(Icons.play_arrow, size: 16),
                    label: Text(workflow.name),
                    selected: selectedNames.contains(workflow.name),
                    onSelected: (selected) => _toggle(workflow.name, selected),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
