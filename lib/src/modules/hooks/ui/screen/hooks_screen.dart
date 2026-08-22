import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/hooks/model/hook.dart';
import 'package:keel_ui/src/modules/hooks/ui/screen/hook_form_screen.dart';
import 'package:keel_ui/src/modules/hooks/ui/widget/hook_tile.dart';
import 'package:keel_ui/src/modules/hooks/viewmodel/hooks_viewmodel.dart';

class HooksScreen extends StatelessWidget {
  const HooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hooks registrados'),
        actions: [
          IconButton(
            tooltip: 'Registrar nuevo',
            icon: const Icon(Icons.add),
            onPressed: () => openHookFormScreen(context),
          ),
        ],
      ),
      body: ReactiveViewModelBuilder<HooksViewModel, HooksState>(
        viewmodel: HooksService.instance.notifier,
        build: (state, viewmodel, keep) {
          if (state.hooks.isEmpty) {
            return const _EmptyHooks();
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: state.hooks.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) => HookTile(hook: state.hooks[index]),
          );
        },
      ),
    );
  }
}

/// La lista vacía explica qué es un hook y en qué se diferencia de una
/// regla: es justo la confusión que hace que uno escriba una regla esperando
/// que se cumpla sola.
class _EmptyHooks extends StatelessWidget {
  const _EmptyHooks();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Todavía no registraste ningún hook.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Un hook es un comando que corre en un momento del turno y '
                'que el agente no puede saltearse: puede frenar una '
                'herramienta antes de que se use, o reaccionar después. '
                'Una regla pide; un hook garantiza.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
