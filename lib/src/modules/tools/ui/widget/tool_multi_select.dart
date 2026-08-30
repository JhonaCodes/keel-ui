import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/modules/tools/model/tool.dart';
import 'package:keel_ui/src/modules/tools/viewmodel/tools_viewmodel.dart';
import 'package:keel_ui/src/modules/tools/ui/screen/tool_form_screen.dart';

/// Toggle-chip picker over the registered tools catalog. Controlled
/// widget — [selectedNames] is the source of truth, [onChanged] reports
/// the next value.
class ToolMultiSelect extends StatelessWidget {
  const ToolMultiSelect({
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
            Text(t.labelTools, style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            TextButton.icon(
              onPressed: () => openToolFormScreen(context),
              icon: const Icon(Icons.add, size: 18),
              label: Text(t.buttonRegister),
            ),
          ],
        ),
        ReactiveViewModelBuilder<ToolsViewModel, ToolsState>(
          viewmodel: ToolsService.instance.notifier,
          build: (state, viewmodel, keep) {
            if (state.tools.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(t.messageNoToolsRegistered),
              );
            }
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tool in state.tools)
                  FilterChip(
                    label: Text(tool.name),
                    selected: selectedNames.contains(tool.name),
                    onSelected: (selected) => _toggle(tool.name, selected),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
