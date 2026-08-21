import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/secrets/model/secret.dart';
import 'package:keel_ui/src/modules/secrets/viewmodel/secrets_viewmodel.dart';
import 'package:keel_ui/src/modules/secrets/ui/screen/secret_form_screen.dart';

class SecretTile extends StatelessWidget {
  const SecretTile({super.key, required this.secret});

  final Secret secret;

  Future<void> _confirmAndDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar secret'),
        content: Text(
          'Se eliminará "${secret.name}". Las tools y MCPs que lo declaran '
          'dejarán de recibirlo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      SecretsService.instance.notifier.deleteSecret(secret.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(
        secret.isPending ? Icons.key_off_outlined : Icons.key_outlined,
        color: secret.isPending ? scheme.error : null,
      ),
      title: Row(
        children: [
          Text(secret.name),
          const SizedBox(width: 8),
          if (secret.isPending)
            Chip(
              label: const Text('pendiente'),
              visualDensity: VisualDensity.compact,
              backgroundColor: scheme.errorContainer,
              labelStyle: TextStyle(color: scheme.onErrorContainer),
            )
          else
            const Text('••••••••', style: TextStyle(letterSpacing: 2)),
        ],
      ),
      subtitle: secret.description.isEmpty
          ? null
          : Text(
              secret.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: secret.isPending ? 'Cargar valor' : 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => openSecretFormScreen(context, initial: secret),
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmAndDelete(context),
          ),
        ],
      ),
    );
  }
}
