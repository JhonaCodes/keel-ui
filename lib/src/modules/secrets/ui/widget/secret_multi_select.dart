import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/secrets/model/secret.dart';
import 'package:keel_ui/src/modules/secrets/ui/screen/secret_form_screen.dart';
import 'package:keel_ui/src/modules/secrets/ui/widget/secret_delete_dialog.dart';
import 'package:keel_ui/src/modules/secrets/viewmodel/secrets_viewmodel.dart';

/// Picker over the registered secrets catalog that also MANAGES what it
/// lists: the row that grants a secret is the row that loads its value when
/// it is pending and the row that deletes it when it no longer belongs. A
/// pending secret used to be a dead end here — the value could only be
/// loaded from the Secrets screen in the rail, which is where "I have the
/// key but I don't know where it goes" came from.
///
/// A credential still has exactly ONE form ([SecretFormScreen]); this widget
/// only routes to it — "Registrar secret" to create one, "Cargar valor" /
/// edit on a row to fill or replace its value. Values never surface here.
///
/// Controlled widget: [selectedNames] in, [onChanged] out.
class SecretMultiSelect extends StatelessWidget {
  const SecretMultiSelect({
    super.key,
    required this.selectedNames,
    required this.onChanged,
  });

  final List<String> selectedNames;
  final ValueChanged<List<String>> onChanged;

  void _toggle(String name, bool selected) {
    if (selected) {
      onChanged([...selectedNames, name]);
    } else {
      onChanged(selectedNames.where((entry) => entry != name).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Secrets (env)', style: theme.textTheme.labelLarge),
            const Spacer(),
            TextButton.icon(
              onPressed: () => openSecretFormScreen(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Registrar secret'),
            ),
          ],
        ),
        Text(
          'Cada secret marcado se inyecta como variable de entorno con su '
          'mismo nombre. El valor se carga acá y nunca se muestra.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        ReactiveViewModelBuilder<SecretsViewModel, SecretsState>(
          viewmodel: SecretsService.instance.notifier,
          build: (state, viewmodel, keep) {
            if (state.secrets.isEmpty) return const _EmptySecretsCatalog();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bounded: the tool form lays this out next to a code editor
                // in a non-scrolling column, so a long catalog scrolls here
                // instead of squeezing the rest of the form.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 232),
                  child: ListView(
                    shrinkWrap: true,
                    primary: false,
                    padding: EdgeInsets.zero,
                    children: [
                      for (final secret in state.secrets)
                        _SecretPickerRow(
                          secret: secret,
                          selected: selectedNames.contains(secret.name),
                          onSelected: (selected) =>
                              _toggle(secret.name, selected),
                          onDeleted: () => _toggle(secret.name, false),
                        ),
                    ],
                  ),
                ),
                _UnresolvedSelectionNotice(
                  pending: viewmodel.pendingOf(selectedNames),
                  missing: viewmodel.missingOf(selectedNames),
                  onDropMissing: (name) => _toggle(name, false),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// One catalog entry: grant checkbox, state, and the actions that state
/// allows. Deleting also drops the grant ([onDeleted]) so the form never
/// saves a reference to a secret that no longer exists.
class _SecretPickerRow extends StatelessWidget {
  const _SecretPickerRow({
    required this.secret,
    required this.selected,
    required this.onSelected,
    required this.onDeleted,
  });

  final Secret secret;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final VoidCallback onDeleted;

  Future<void> _delete(BuildContext context) async {
    final deleted = await confirmDeleteSecret(context, secret);
    if (deleted) onDeleted();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      horizontalTitleGap: 4,
      onTap: () => onSelected(!selected),
      leading: Checkbox(
        value: selected,
        onChanged: (value) => onSelected(value ?? false),
      ),
      title: Text(secret.name, overflow: TextOverflow.ellipsis),
      subtitle: _SecretStatusLine(secret: secret),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (secret.isPending)
            TextButton.icon(
              onPressed: () => openSecretFormScreen(context, initial: secret),
              icon: const Icon(Icons.vpn_key_outlined, size: 18),
              label: const Text('Cargar valor'),
            )
          else
            IconButton(
              tooltip: 'Cambiar valor',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => openSecretFormScreen(context, initial: secret),
            ),
          IconButton(
            tooltip: 'Eliminar secret',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context),
          ),
        ],
      ),
    );
  }
}

/// Whether the credential is loaded, said with an icon and words — never
/// with colour alone.
class _SecretStatusLine extends StatelessWidget {
  const _SecretStatusLine({required this.secret});

  final Secret secret;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!secret.isPending) {
      return const Text('•••••••• valor cargado');
    }
    return Row(
      children: [
        Icon(Icons.key_off_outlined, size: 14, color: scheme.error),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Pendiente: sin valor',
            style: TextStyle(color: scheme.error),
          ),
        ),
      ],
    );
  }
}

/// Says, before saving, which granted secrets will NOT reach the process —
/// the gap between "marqué el secret" and "el MCP arranca con la clave".
class _UnresolvedSelectionNotice extends StatelessWidget {
  const _UnresolvedSelectionNotice({
    required this.pending,
    required this.missing,
    required this.onDropMissing,
  });

  final List<String> pending;
  final List<String> missing;
  final ValueChanged<String> onDropMissing;

  @override
  Widget build(BuildContext context) {
    if (pending.isEmpty && missing.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pending.isNotEmpty)
            Text(
              'Sin valor: ${pending.join(', ')}. El proceso arranca sin esa '
              'variable hasta que la cargues con «Cargar valor».',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          if (missing.isNotEmpty) ...[
            if (pending.isNotEmpty) const SizedBox(height: 8),
            Text(
              'Ya no existen: ${missing.join(', ')}. Quedaron marcados de '
              'antes; registralos de nuevo o soltá el permiso.',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                for (final name in missing)
                  TextButton(
                    onPressed: () => onDropMissing(name),
                    child: Text('Soltar $name'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptySecretsCatalog extends StatelessWidget {
  const _EmptySecretsCatalog();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'Todavía no registraste ningún secret. Usá «Registrar secret» y '
        'nombralo como la variable de entorno que el proceso espera '
        '(ej: LINEAR_API_KEY).',
      ),
    );
  }
}
