import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/modules/knowledge/ui/screen/knowledge_base_form_screen.dart';
import 'package:keel_ui/src/modules/knowledge/viewmodel/knowledge_viewmodel.dart';

/// Selector de bases de saber. Widget controlado: [selectedNames] manda,
/// [onChanged] informa el próximo valor.
class KnowledgeBaseMultiSelect extends StatelessWidget {
  const KnowledgeBaseMultiSelect({
    super.key,
    required this.selectedNames,
    required this.onChanged,
    this.title = 'Bases de saber',
  });

  final List<String> selectedNames;
  final ValueChanged<List<String>> onChanged;
  final String title;

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
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            TextButton.icon(
              onPressed: () => openKnowledgeBaseFormScreen(context),
              icon: const Icon(Icons.add, size: 18),
              label: Text(t.buttonNewKnowledgeBase),
            ),
          ],
        ),
        ReactiveViewModelBuilder<KnowledgeViewModel, KnowledgeState>(
          viewmodel: KnowledgeService.instance.notifier,
          build: (state, viewmodel, keep) {
            if (state.bases.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(t.messageNoKnowledgeBasesYet),
              );
            }
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final base in state.bases)
                  FilterChip(
                    label: Text(base.name),
                    tooltip: base.description.isEmpty ? null : base.description,
                    selected: selectedNames.contains(base.name),
                    onSelected: (selected) => _toggle(base.name, selected),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
