import 'package:flutter/material.dart';

import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/secrets/model/secret.dart';
import 'package:keel_ui/src/modules/secrets/viewmodel/secrets_viewmodel.dart';

Future<void> openSecretFormScreen(BuildContext context, {Secret? initial}) {
  return showFormPanel<void>(
    context,
    child: SecretFormScreen(initial: initial),
  );
}

/// Registering a credential is two facts and nothing else: the NAME of the
/// environment variable the process expects, and the value. The old form
/// also asked for a description, and it read like a second name slot —
/// people typed the real variable name into it and left the actual name
/// wrong. The description still exists in the model (an agent explains
/// there why it asked for the key), but it is shown as context, not as a
/// field to fill.
class SecretFormScreen extends StatefulWidget {
  const SecretFormScreen({super.key, this.initial});

  final Secret? initial;

  @override
  State<SecretFormScreen> createState() => _SecretFormScreenState();
}

class _SecretFormScreenState extends State<SecretFormScreen> {
  late final _nameController = TextEditingController(
    text: widget.initial?.name,
  );
  // NEVER prefilled with the stored value — the form is write-only for the
  // credential; leaving it empty on edit keeps the existing value.
  final _valueController = TextEditingController();

  /// A secret that already holds a value shows that it does and keeps the
  /// input hidden until the user asks to replace it — an empty box next to
  /// a loaded key reads as "it is not saved" every single time.
  late bool _editingValue = widget.initial?.isPending ?? true;

  String? _nameError;
  String? _formError;

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    setState(() {
      _nameError = validateSecretName(value.trim());
      _formError = null;
    });
  }

  void _submit() {
    final name = _nameController.text.trim();
    final nameError = validateSecretName(name);
    if (nameError != null) {
      setState(() => _nameError = nameError);
      return;
    }

    final viewmodel = SecretsService.instance.notifier;
    final initial = widget.initial;
    final error = initial == null
        ? viewmodel.createSecret(
            name: name,
            description: '',
            value: _valueController.text,
          )
        : viewmodel.updateSecret(
            initial.id,
            name: name,
            // Carried through, not edited here: it is the agent's reason
            // for asking, and the user has no field for it any more.
            description: initial.description,
            value: _valueController.text,
          );

    if (error != null) {
      setState(() => _formError = error);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initial;
    final isEditing = initial != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar secret' : 'Registrar secret'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: FilledButton(
              onPressed: _submit,
              child: Text(isEditing ? 'Guardar' : 'Registrar'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameController,
                  autofocus: !isEditing,
                  onChanged: _onNameChanged,
                  decoration: InputDecoration(
                    labelText: 'Nombre de la variable de entorno',
                    hintText: 'LINEAR_API_KEY',
                    helperText:
                        'Tal cual la espera el proceso: MAYÚSCULAS, números '
                        'y "_". Es el nombre con el que se inyecta.',
                    errorText: _nameError,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_editingValue)
                  TextField(
                    controller: _valueController,
                    autofocus: isEditing,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: isEditing && !initial.isPending
                          ? 'Valor nuevo (vacío = conservar el actual)'
                          : 'Valor',
                      helperText:
                          'Nunca pasa por un modelo: se inyecta como '
                          'variable de entorno solo a tools y MCPs que lo '
                          'declaren.',
                      helperMaxLines: 3,
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                    ),
                  )
                else
                  _StoredValueRow(
                    onReplace: () => setState(() => _editingValue = true),
                  ),
                if (isEditing && initial.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _RequestedReason(reason: initial.description),
                ],
                if (_formError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _formError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The value is set. Says so — masked, but unmistakably present — instead
/// of showing an empty input the user has to interpret.
class _StoredValueRow extends StatelessWidget {
  const _StoredValueRow({required this.onReplace});

  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          const Expanded(child: Text('Valor cargado  ••••••••')),
          TextButton(onPressed: onReplace, child: const Text('Reemplazar')),
        ],
      ),
    );
  }
}

/// Why this key exists, when an agent was the one that asked for it.
class _RequestedReason extends StatelessWidget {
  const _RequestedReason({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 16, color: theme.colorScheme.outline),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Para qué se pidió: $reason',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
