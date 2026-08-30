import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/modules/secrets/model/secret.dart';
import 'package:keel_ui/src/modules/secrets/viewmodel/secrets_viewmodel.dart';
import 'package:keel_ui/src/modules/secrets/ui/screen/secret_form_screen.dart';
import 'package:keel_ui/src/modules/secrets/ui/widget/secret_tile.dart';
import 'package:keel_ui/src/modules/secrets/ui/widget/provider_credential_card.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';

class SecretsScreen extends StatelessWidget {
  const SecretsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.pageTitleSecrets),
        actions: [
          IconButton(
            tooltip: t.tooltipRegisterNew,
            icon: const Icon(Icons.add),
            onPressed: () => openSecretFormScreen(context),
          ),
        ],
      ),
      body: ReactiveViewModelBuilder<SecretsViewModel, SecretsState>(
        viewmodel: SecretsService.instance.notifier,
        build: (state, viewmodel, keep) {
          final providerSecretNames = {
            AgentProvider.openRouter.secretName,
            AgentProvider.deepSeek.secretName,
          };
          final remaining = state.secrets
              .where((entry) => !providerSecretNames.contains(entry.name))
              .toList();
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  t.labelLlmProviders,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              const ProviderCredentialCard(provider: AgentProvider.openRouter),
              const ProviderCredentialCard(provider: AgentProvider.deepSeek),
              if (remaining.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                  child: Text(
                    t.labelOtherSecrets,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                for (final secret in remaining) ...[
                  SecretTile(secret: secret),
                  const Divider(height: 1),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}
