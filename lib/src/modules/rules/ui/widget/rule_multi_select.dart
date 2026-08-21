import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/rules/model/rule.dart';
import 'package:keel_ui/src/modules/rules/viewmodel/rules_viewmodel.dart';
import 'package:keel_ui/src/modules/rules/ui/screen/rule_form_screen.dart';

/// Toggle-chip picker over the registered rules catalog. Controlled
/// widget — [selectedNames] is the source of truth, [onChanged] reports
/// the next value.
class RuleMultiSelect extends StatelessWidget {
  const RuleMultiSelect({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Reglas', style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            TextButton.icon(
              onPressed: () => openRuleFormScreen(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Registrar regla'),
            ),
          ],
        ),
        ReactiveViewModelBuilder<RulesViewModel, RulesState>(
          viewmodel: RulesService.instance.notifier,
          build: (state, viewmodel, keep) {
            if (state.rules.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Todavía no registraste ninguna regla.'),
              );
            }
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final rule in state.rules)
                  FilterChip(
                    label: Text(rule.name),
                    selected: selectedNames.contains(rule.name),
                    onSelected: (selected) => _toggle(rule.name, selected),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
