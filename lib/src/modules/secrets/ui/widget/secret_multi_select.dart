import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/secrets/model/secret.dart';
import 'package:keel_ui/src/modules/secrets/viewmodel/secrets_viewmodel.dart';
import 'package:keel_ui/src/modules/secrets/ui/screen/secret_form_screen.dart';

/// Toggle-chip picker over the registered secrets catalog (names only —
/// values never surface here). Controlled widget.
class SecretMultiSelect extends StatelessWidget {
  const SecretMultiSelect({
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
            Text('Secrets (env)', style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            TextButton.icon(
              onPressed: () => openSecretFormScreen(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Registrar secret'),
            ),
          ],
        ),
        ReactiveViewModelBuilder<SecretsViewModel, SecretsState>(
          viewmodel: SecretsService.instance.notifier,
          build: (state, viewmodel, keep) {
            if (state.secrets.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Todavía no registraste ningún secret.'),
              );
            }
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final secret in state.secrets)
                  FilterChip(
                    label: Text(
                      secret.isPending
                          ? '${secret.name} (pendiente)'
                          : secret.name,
                    ),
                    selected: selectedNames.contains(secret.name),
                    onSelected: (selected) => _toggle(secret.name, selected),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
