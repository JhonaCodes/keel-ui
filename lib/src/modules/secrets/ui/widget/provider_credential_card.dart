import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/modules/secrets/model/secret.dart';
import 'package:keel_ui/src/modules/secrets/ui/screen/secret_form_screen.dart';
import 'package:keel_ui/src/modules/secrets/viewmodel/secrets_viewmodel.dart';

/// Write-only status and shortcut for a provider credential. The actual
/// value is never rendered or passed back to the form.
class ProviderCredentialCard extends StatelessWidget {
  const ProviderCredentialCard({
    super.key,
    required this.provider,
    this.compact = false,
  });

  final AgentProvider provider;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final secretName = provider.secretName;
    if (secretName == null) return const SizedBox.shrink();
    return ReactiveViewModelBuilder<SecretsViewModel, SecretsState>(
      viewmodel: SecretsService.instance.notifier,
      build: (state, viewmodel, keep) {
        final secret = state.secrets
            .where((entry) => entry.name == secretName)
            .firstOrNull;
        final configured = secret != null && !secret.isPending;
        return _ProviderCredentialContent(
          provider: provider,
          secretName: secretName,
          secret: secret,
          configured: configured,
          compact: compact,
        );
      },
    );
  }
}

class _ProviderCredentialContent extends StatelessWidget {
  const _ProviderCredentialContent({
    required this.provider,
    required this.secretName,
    required this.secret,
    required this.configured,
    required this.compact,
  });

  final AgentProvider provider;
  final String secretName;
  final Secret? secret;
  final bool configured;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: compact
          ? const EdgeInsets.symmetric(vertical: 3)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 7 : 11,
        ),
        child: Row(
          children: [
            Icon(
              configured ? Icons.key : Icons.key_off_outlined,
              size: compact ? 15 : 19,
              color: configured ? scheme.tertiary : scheme.error,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.label,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    secretName,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    configured ? 'configurada' : 'faltante',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: configured ? scheme.tertiary : scheme.error,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => openSecretFormScreen(
                context,
                initial: secret,
                suggestedName: secretName,
              ),
              child: Text(configured ? 'Reemplazar' : 'Configurar'),
            ),
          ],
        ),
      ),
    );
  }
}
