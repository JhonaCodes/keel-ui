import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/modules/hooks/model/hook.dart';
import 'package:keel_ui/src/modules/hooks/ui/screen/hook_form_screen.dart';
import 'package:keel_ui/src/modules/hooks/ui/screen/hook_import_screen.dart';
import 'package:keel_ui/src/modules/hooks/ui/widget/hook_tile.dart';
import 'package:keel_ui/src/modules/hooks/viewmodel/hooks_viewmodel.dart';

class HooksScreen extends StatelessWidget {
  const HooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.pageTitleHooksRegistered),
        actions: [
          IconButton(
            tooltip: t.pageTitleImportHooks,
            icon: const Icon(Icons.download_outlined),
            onPressed: () => openHookImportScreen(context),
          ),
          IconButton(
            tooltip: t.tooltipRegisterNew,
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
    final t = AppLocalizations.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.messageNoHooksRegistered,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                t.messageNoHooksDescription,
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
