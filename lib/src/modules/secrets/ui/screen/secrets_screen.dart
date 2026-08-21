import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/secrets/model/secret.dart';
import 'package:keel_ui/src/modules/secrets/viewmodel/secrets_viewmodel.dart';
import 'package:keel_ui/src/modules/secrets/ui/screen/secret_form_screen.dart';
import 'package:keel_ui/src/modules/secrets/ui/widget/secret_tile.dart';

class SecretsScreen extends StatelessWidget {
  const SecretsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secrets'),
        actions: [
          IconButton(
            tooltip: 'Registrar nuevo',
            icon: const Icon(Icons.add),
            onPressed: () => openSecretFormScreen(context),
          ),
        ],
      ),
      body: ReactiveViewModelBuilder<SecretsViewModel, SecretsState>(
        viewmodel: SecretsService.instance.notifier,
        build: (state, viewmodel, keep) {
          if (state.secrets.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavía no registraste ningún secret.\n\n'
                  'Los valores nunca pasan por un modelo: se inyectan como '
                  'variables de entorno solo a procesos deterministas (tools '
                  'y MCPs externos).',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: state.secrets.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                SecretTile(secret: state.secrets[index]),
          );
        },
      ),
    );
  }
}
