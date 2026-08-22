import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/integrations/mcp_catalog/mcp_catalog.dart';
import 'package:keel_ui/src/modules/secrets/model/secret.dart';
import 'package:keel_ui/src/modules/secrets/ui/screen/secret_form_screen.dart';
import 'package:keel_ui/src/modules/secrets/viewmodel/secrets_viewmodel.dart';

/// Las credenciales que una ficha del catálogo declara, con su estado.
///
/// Reemplaza al campo vacío: en vez de "pegá acá un KEY=VALUE", dice cómo se
/// llama la credencial en la documentación del servicio, dónde se saca, y si
/// ya está cargada. El valor no aparece nunca: se resuelve recién adentro
/// del archivo temporal del turno.
class IntegrationCredentials extends StatelessWidget {
  const IntegrationCredentials({super.key, required this.entry});

  final McpCatalogEntry entry;

  @override
  Widget build(BuildContext context) {
    if (entry.credentials.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ReactiveViewModelBuilder<SecretsViewModel, SecretsState>(
      viewmodel: SecretsService.instance.notifier,
      build: (state, viewmodel, keep) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'CREDENCIALES QUE PIDE',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                letterSpacing: 1.2,
                color: scheme.outline,
              ),
            ),
            const SizedBox(height: 10),
            for (final credential in entry.credentials)
              _CredentialRow(
                credential: credential,
                secret: state.secrets
                    .where((secret) => secret.name == credential.name)
                    .firstOrNull,
              ),
          ],
        );
      },
    );
  }
}

class _CredentialRow extends StatelessWidget {
  const _CredentialRow({required this.credential, required this.secret});

  final McpCredential credential;
  final Secret? secret;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (icon, color, status) = switch (secret) {
      null => (Icons.key_off_outlined, scheme.error, 'todavía no existe'),
      Secret(isPending: true) => (
        Icons.key_off_outlined,
        scheme.error,
        'existe pero está vacío',
      ),
      _ => (Icons.key_outlined, scheme.tertiary, 'cargado'),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: credential.name,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: '  ${credential.label} · $status',
                        style: TextStyle(color: color),
                      ),
                    ],
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  credential.hint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.outline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => openSecretFormScreen(
              context,
              initial: secret,
              suggestedName: credential.name,
            ),
            child: Text(secret == null ? 'Crear' : 'Editar'),
          ),
        ],
      ),
    );
  }
}
