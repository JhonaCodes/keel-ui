import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/modules/hooks/model/hook.dart';
import 'package:keel_ui/src/modules/hooks/ui/screen/hook_form_screen.dart';
import 'package:keel_ui/src/modules/hooks/viewmodel/hooks_viewmodel.dart';

/// Selector de hooks sobre el catálogo registrado. Controlado:
/// [selectedNames] es la fuente de verdad y [onChanged] reporta el próximo
/// valor.
///
/// Los globales aparecen marcados y no se pueden destildar desde acá: ya
/// corren para todos, y dejarlos tildables haría creer que se los puede
/// sacar de un agente en particular.
class HookMultiSelect extends StatelessWidget {
  const HookMultiSelect({
    super.key,
    required this.selectedNames,
    required this.onChanged,
  });

  final List<String> selectedNames;
  final ValueChanged<List<String>> onChanged;

  void _toggle(String name, bool selected) {
    if (selected) {
      onChanged([...selectedNames, name]);
      return;
    }
    onChanged(selectedNames.where((entry) => entry != name).toList());
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(t.labelHooks, style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            TextButton.icon(
              onPressed: () => openHookFormScreen(context),
              icon: const Icon(Icons.add, size: 18),
              label: Text(t.buttonRegister),
            ),
          ],
        ),
        ReactiveViewModelBuilder<HooksViewModel, HooksState>(
          viewmodel: HooksService.instance.notifier,
          build: (state, viewmodel, keep) {
            if (state.hooks.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(t.messageNoHooksRegistered),
              );
            }
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final hook in state.hooks)
                  FilterChip(
                    label: Text(
                      hook.isGlobal
                          ? '${hook.name} (${t.labelGlobal})'
                          : hook.name,
                    ),
                    avatar: hook.enabled
                        ? null
                        : const Icon(Icons.pause_circle_outline, size: 16),
                    selected:
                        hook.isGlobal || selectedNames.contains(hook.name),
                    onSelected: hook.isGlobal
                        ? null
                        : (selected) => _toggle(hook.name, selected),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
