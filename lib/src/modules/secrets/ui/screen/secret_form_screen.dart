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
  late final _descriptionController = TextEditingController(
    text: widget.initial?.description,
  );
  // NEVER prefilled with the stored value — the form is write-only for the
  // credential; leaving it empty on edit keeps the existing value.
  final _valueController = TextEditingController();
  String? _nameError;
  String? _formError;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
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
            description: _descriptionController.text,
            value: _valueController.text,
          )
        : viewmodel.updateSecret(
            initial.id,
            name: name,
            description: _descriptionController.text,
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
                    labelText:
                        'Nombre (formato variable de entorno: MI_API_KEY)',
                    errorText: _nameError,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Para qué es (visible; el valor no lo es)',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _valueController,
                  autofocus: isEditing,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: isEditing
                        ? (initial.isPending
                              ? 'Valor (PENDIENTE — cargalo acá)'
                              : 'Valor nuevo (vacío = conservar el actual)')
                        : 'Valor',
                    helperText:
                        'Nunca pasa por un modelo: se inyecta como variable '
                        'de entorno solo a tools y MCPs que lo declaren.',
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                ),
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
