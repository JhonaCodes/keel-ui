import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/catalog_locks/model/catalog_lock.dart';
import 'package:keel_ui/src/modules/catalog_locks/ui/widget/catalog_lock_button.dart';
import 'package:keel_ui/src/modules/catalog_locks/viewmodel/catalog_locks_viewmodel.dart';
import 'package:keel_ui/src/modules/hooks/model/hook.dart';
import 'package:keel_ui/src/modules/hooks/ui/screen/hook_form_screen.dart';
import 'package:keel_ui/src/modules/hooks/viewmodel/hooks_viewmodel.dart';

class HookTile extends StatelessWidget {
  const HookTile({super.key, required this.hook});

  final Hook hook;

  /// Borrar un hook lo saca de TODOS lados, así que el diálogo dice
  /// exactamente qué está soltando antes de hacerlo. Una lista de
  /// asignaciones que apunta a un guardarraíl borrado miente sobre qué está
  /// protegido — por eso no se deja colgada, y por eso hay que avisarlo.
  Future<void> _confirmAndDelete(BuildContext context) async {
    final viewmodel = HooksService.instance.notifier;
    final assignments = viewmodel.assignmentsOf(hook.name);
    final attached = [
      if (assignments.profiles > 0)
        '${assignments.profiles} '
            '${assignments.profiles == 1 ? 'agente' : 'agentes'}',
      if (assignments.projects > 0)
        '${assignments.projects} '
            '${assignments.projects == 1 ? 'proyecto' : 'proyectos'}',
    ];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar hook'),
        content: Text(
          attached.isEmpty
              ? 'Se eliminará el hook "${hook.name}". No lo tiene asignado '
                    'nadie.'
              : 'Se eliminará el hook "${hook.name}" y se quitará de '
                    '${attached.join(' y ')}. Eso que dejaba de pasar, '
                    'vuelve a poder pasar.',
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

    if (confirmed ?? false) viewmodel.deleteHook(hook.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLocked = CatalogLocksService.instance.notifier.isLocked(
      CatalogLockKind.hook,
      hook.name,
    );
    final subtitle = [
      hook.event.label,
      if (hook.matcher.isNotEmpty) 'en ${hook.matcher}',
      if (!hook.event.isPortable) 'solo Claude',
      if (hook.isGlobal) 'global',
    ].join(' · ');

    return ListTile(
      leading: Tooltip(
        message: hook.enabled ? 'Activo' : 'Apagado',
        child: Switch(
          value: hook.enabled,
          onChanged: isLocked
              ? null
              : (value) =>
                    HooksService.instance.notifier.setEnabled(hook.id, value),
        ),
      ),
      title: Text(
        hook.name,
        style: hook.enabled
            ? null
            : TextStyle(color: theme.colorScheme.onSurfaceVariant),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle, style: theme.textTheme.bodySmall),
          if (hook.enforces.isNotEmpty)
            Text(
              'Hace cumplir: ${hook.enforces.join(', ')}',
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CatalogLockButton(kind: CatalogLockKind.hook, name: hook.name),
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: isLocked
                ? null
                : () => openHookFormScreen(context, initial: hook),
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline),
            onPressed: isLocked ? null : () => _confirmAndDelete(context),
          ),
        ],
      ),
    );
  }
}
