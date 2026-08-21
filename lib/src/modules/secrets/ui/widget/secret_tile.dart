import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/secrets/model/secret.dart';
import 'package:keel_ui/src/modules/secrets/ui/screen/secret_form_screen.dart';
import 'package:keel_ui/src/modules/secrets/ui/widget/secret_delete_dialog.dart';

class SecretTile extends StatelessWidget {
  const SecretTile({super.key, required this.secret});

  final Secret secret;

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
            onPressed: () => confirmDeleteSecret(context, secret),
          ),
        ],
      ),
    );
  }
}
