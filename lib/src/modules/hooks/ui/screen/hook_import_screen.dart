import 'package:flutter/material.dart';

import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/integrations/hook_import/hook_import.dart';
import 'package:keel_ui/src/modules/hooks/model/hook.dart';
import 'package:keel_ui/src/modules/hooks/viewmodel/hooks_viewmodel.dart';

Future<void> openHookImportScreen(BuildContext context) {
  return showFormPanel<void>(
    context,
    width: 720,
    child: const HookImportScreen(),
  );
}

/// Rescata los hooks que ya estaban escritos a mano en la configuración de
/// Claude Code.
///
/// Entran TODOS apagados: una config vieja suele apuntar a scripts que ya no
/// están, y prenderlos sin mirar llenaría cada turno de errores. Lo que se
/// recupera es la intención —qué guardabas y en qué momento— para que
/// decidas qué reconstruir.
class HookImportScreen extends StatefulWidget {
  const HookImportScreen({super.key});

  @override
  State<HookImportScreen> createState() => _HookImportScreenState();
}

class _HookImportScreenState extends State<HookImportScreen> {
  late final List<ImportableHook> _found = readAllClaudeHooks();
  late final Set<String> _selected = {for (final hook in _found) hook.name};
  String? _result;

  void _import() {
    final viewmodel = HooksService.instance.notifier;
    var created = 0;
    final skipped = <String>[];

    for (final hook in _found) {
      if (!_selected.contains(hook.name)) continue;
      if (viewmodel.hookByName(hook.name) != null) {
        skipped.add(hook.name);
        continue;
      }
      final error = viewmodel.createHook(
        name: hook.name,
        description: hook.isBroken
            ? 'Importado de Claude Code. Su comando apunta a algo que no '
                  'existe en esta máquina.'
            : 'Importado de Claude Code.',
        event: hook.event,
        body: HookCommand(hook.command),
        matcher: hook.matcher,
        timeoutSeconds: hook.timeoutSeconds,
        // Apagados SIEMPRE. Prender uno roto sería llenar cada turno de
        // errores por algo que el usuario no pidió.
        enabled: false,
      );
      if (error == null) created++;
    }

    setState(() {
      _result = [
        'Importé $created hooks, todos apagados.',
        if (skipped.isNotEmpty) 'Ya existían: ${skipped.join(', ')}.',
        'Revisá cada uno y prendé los que sigas queriendo.',
      ].join(' ');
    });
  }

  @override
  Widget build(BuildContext context) {
    final broken = _found.where((hook) => hook.isBroken).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar hooks de Claude Code'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _selected.isEmpty ? null : _import,
              child: const Text('Importar'),
            ),
          ),
        ],
      ),
      body: _found.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No encontré hooks en tu configuración de Claude Code.',
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Encontré ${_found.length} hooks escritos a mano en tu '
                  'configuración de Claude Code'
                  '${broken == 0 ? '' : ', y $broken apuntan a archivos que ya '
                        'no existen'}. '
                  'Entran todos APAGADOS: recuperás qué guardabas y en qué '
                  'momento, sin que se prenda nada roto.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                for (final hook in _found)
                  _ImportRow(
                    hook: hook,
                    selected: _selected.contains(hook.name),
                    onChanged: (value) => setState(() {
                      if (value) {
                        _selected.add(hook.name);
                        return;
                      }
                      _selected.remove(hook.name);
                    }),
                  ),
                if (_result != null) ...[
                  const SizedBox(height: 16),
                  SelectableText(
                    _result!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
    );
  }
}

class _ImportRow extends StatelessWidget {
  const _ImportRow({
    required this.hook,
    required this.selected,
    required this.onChanged,
  });

  final ImportableHook hook;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = [
      hook.event.label,
      if (hook.matcher.isNotEmpty) 'en ${hook.matcher}',
    ].join(' · ');

    return CheckboxListTile(
      value: selected,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(hook.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(detail, style: theme.textTheme.bodySmall),
          Text(
            hook.command,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (hook.isBroken)
            Text(
              'El archivo que ejecuta ya no existe.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
      onChanged: (value) => onChanged(value ?? false),
    );
  }
}
