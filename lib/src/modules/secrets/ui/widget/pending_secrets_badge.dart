import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/secrets/model/secret.dart';
import 'package:keel_ui/src/modules/secrets/viewmodel/secrets_viewmodel.dart';

/// Marks, wherever something that DECLARES secrets is listed, that some of
/// them will not be injected — the difference between "registered" and
/// "actually usable". Renders nothing when every declared secret has a
/// value, so a healthy row stays quiet.
class PendingSecretsBadge extends StatelessWidget {
  const PendingSecretsBadge({super.key, required this.secretNames});

  /// Secret NAMES the listed thing declares (`Tool.secretNames`,
  /// `McpServerConfig.secretNames`).
  final List<String> secretNames;

  @override
  Widget build(BuildContext context) {
    if (secretNames.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return ReactiveViewModelBuilder<SecretsViewModel, SecretsState>(
      viewmodel: SecretsService.instance.notifier,
      build: (state, viewmodel, keep) {
        final unresolved = [
          ...viewmodel.pendingOf(secretNames),
          ...viewmodel.missingOf(secretNames),
        ];
        if (unresolved.isEmpty) return const SizedBox.shrink();

        return Tooltip(
          message: 'No se inyectan: ${unresolved.join(', ')}',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.key_off_outlined,
                size: 16,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 4),
              Text(
                'falta la clave',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
