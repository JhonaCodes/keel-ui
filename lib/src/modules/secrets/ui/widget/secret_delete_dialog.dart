import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/secrets/model/secret.dart';
import 'package:keel_ui/src/modules/secrets/viewmodel/secrets_viewmodel.dart';

/// Asks for confirmation and deletes [secret]. Shared by every surface that
/// lists secrets (the registry and the pickers) so what deletion costs is
/// stated once, in one wording. Returns whether it was actually deleted.
Future<bool> confirmDeleteSecret(BuildContext context, Secret secret) async {
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

  if (!(confirmed ?? false)) return false;
  SecretsService.instance.notifier.deleteSecret(secret.id);
  return true;
}
