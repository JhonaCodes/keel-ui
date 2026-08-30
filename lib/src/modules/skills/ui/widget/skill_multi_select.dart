import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/modules/skills/model/skill.dart';
import 'package:keel_ui/src/modules/skills/viewmodel/skills_viewmodel.dart';
import 'package:keel_ui/src/modules/skills/ui/screen/skill_form_screen.dart';

/// Toggle-chip picker over the registered skills catalog. Controlled
/// widget — [selectedNames] is the source of truth, [onChanged] reports
/// the next value.
class SkillMultiSelect extends StatelessWidget {
  const SkillMultiSelect({
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
            Text(t.labelSkills, style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            TextButton.icon(
              onPressed: () => openSkillFormScreen(context),
              icon: const Icon(Icons.add, size: 18),
              label: Text(t.buttonRegisterSkill),
            ),
          ],
        ),
        ReactiveViewModelBuilder<SkillsViewModel, SkillsState>(
          viewmodel: SkillsService.instance.notifier,
          build: (state, viewmodel, keep) {
            if (state.skills.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(t.messageNoSkillsRegistered),
              );
            }
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final skill in state.skills)
                  FilterChip(
                    label: Text(skill.name),
                    selected: selectedNames.contains(skill.name),
                    onSelected: (selected) => _toggle(skill.name, selected),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
