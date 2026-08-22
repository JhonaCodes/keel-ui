import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';

/// The role is how a workflow step finds its agent: the step names a role, and
/// the project looks for the member whose role matches. Both sides are free
/// text, so typing them independently is how you end up with
/// `sin agente para "Revisor"`.
///
/// This field closes that gap by offering the roles the registered workflows
/// actually ask for — picking one guarantees the match instead of hoping for
/// it — while still accepting a role nobody asks for yet.
class RoleField extends StatelessWidget {
  const RoleField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<WorkflowsViewModel, WorkflowsState>(
      viewmodel: WorkflowsService.instance.notifier,
      build: (state, viewmodel, keep) {
        final wanted = _rolesWantedBy(state.workflows);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Rol',
                hintText: 'Qué hace este agente',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
            ),
            if (wanted.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  'Los pasos de un workflow buscan a su agente por este texto.',
                  style: TextStyle(fontSize: 11),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(top: 10, left: 4, bottom: 6),
                child: Text(
                  'Roles que piden tus workflows — tocá uno para que este '
                  'agente los cubra:',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              ListenableBuilder(
                listenable: controller,
                builder: (context, child) => _RoleSuggestions(
                  roles: wanted,
                  selected: controller.text.trim().toLowerCase(),
                  onPick: (role) => controller.text = role,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Every distinct role named by a step, with the workflows that ask for it —
  /// so the user can see *why* a role matters before assigning it.
  static List<_WantedRole> _rolesWantedBy(List<Workflow> workflows) {
    final byRole = <String, _WantedRole>{};
    for (final workflow in workflows) {
      for (final step in workflow.steps) {
        final role = step.role.trim();
        if (role.isEmpty) continue;
        final key = role.toLowerCase();
        final existing = byRole[key];
        if (existing == null) {
          byRole[key] = _WantedRole(role, {workflow.name});
          continue;
        }
        existing.workflows.add(workflow.name);
      }
    }
    return byRole.values.toList();
  }
}

class _WantedRole {
  final String role;
  final Set<String> workflows;

  _WantedRole(this.role, this.workflows);
}

class _RoleSuggestions extends StatelessWidget {
  const _RoleSuggestions({
    required this.roles,
    required this.selected,
    required this.onPick,
  });

  final List<_WantedRole> roles;
  final String selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final wanted in roles)
          Tooltip(
            message: 'Lo piden: ${wanted.workflows.join(', ')}',
            child: ChoiceChip(
              label: Text(wanted.role),
              selected: wanted.role.toLowerCase() == selected,
              onSelected: (_) => onPick(wanted.role),
            ),
          ),
      ],
    );
  }
}
