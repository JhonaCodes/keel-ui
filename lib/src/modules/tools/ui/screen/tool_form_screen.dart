import 'package:flutter/material.dart';

import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/secrets/ui/widget/secret_multi_select.dart';
import 'package:keel_ui/src/modules/agents/model/code_language.dart';
import 'package:keel_ui/src/modules/agents/model/highlighted_line.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/code_editing_controller.dart';
import 'package:keel_ui/src/modules/tools/model/tool.dart';
import 'package:keel_ui/src/modules/tools/viewmodel/tools_viewmodel.dart';

Future<void> openToolFormScreen(BuildContext context, {Tool? initial}) {
  return showFormPanel<void>(context, child: ToolFormScreen(initial: initial));
}

class ToolFormScreen extends StatefulWidget {
  const ToolFormScreen({super.key, this.initial});

  final Tool? initial;

  @override
  State<ToolFormScreen> createState() => _ToolFormScreenState();
}

class _ToolFormScreenState extends State<ToolFormScreen> {
  late final _nameController = TextEditingController(
    text: widget.initial?.name,
  );
  late final _descriptionController = TextEditingController(
    text: widget.initial?.description,
  );

  /// Pinta la sintaxis mientras se edita, en vez de dejar el script como un
  /// bloque de texto plano: es código, y leerlo sin colores es lo que hace
  /// que un `fi` de más pase desapercibido.
  late final _codeController = CodeEditingController(
    language: _languageOf(widget.initial?.runtime ?? ToolRuntime.bash),
    theme: codeHighlightTheme(Brightness.dark),
    text: widget.initial?.code,
  );

  static String _languageOf(ToolRuntime runtime) =>
      codeLanguageForPath('script.${runtime.fileExtension}');
  late final _timeoutController = TextEditingController(
    text: (widget.initial?.timeoutSeconds ?? kDefaultToolTimeoutSeconds)
        .toString(),
  );
  late ToolRuntime _runtime = widget.initial?.runtime ?? ToolRuntime.bash;
  late List<String> _secretNames = [...?widget.initial?.secretNames];
  String? _nameError;
  String? _formError;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _codeController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    setState(() {
      _nameError = validateToolName(value.trim());
      _formError = null;
    });
  }

  void _submit() {
    final name = _nameController.text.trim();
    final nameError = validateToolName(name);
    if (nameError != null) {
      setState(() => _nameError = nameError);
      return;
    }

    final timeoutSeconds =
        int.tryParse(_timeoutController.text.trim()) ??
        kDefaultToolTimeoutSeconds;

    final viewmodel = ToolsService.instance.notifier;
    final initial = widget.initial;
    final error = initial == null
        ? viewmodel.createTool(
            name: name,
            description: _descriptionController.text,
            runtime: _runtime,
            code: _codeController.text,
            timeoutSeconds: timeoutSeconds,
            secretNames: _secretNames,
          )
        : viewmodel.updateTool(
            initial.id,
            name: name,
            description: _descriptionController.text,
            runtime: _runtime,
            code: _codeController.text,
            timeoutSeconds: timeoutSeconds,
            secretNames: _secretNames,
          );

    if (error != null) {
      setState(() => _formError = error);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar tool' : 'Registrar tool'),
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  onChanged: _onNameChanged,
                  decoration: InputDecoration(
                    labelText:
                        'Nombre (minúsculas, sin espacios, máx. 32) — es el '
                        'nombre de tool que ve el agente',
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
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText:
                        'Descripción para el agente: qué hace, cuándo usarla '
                        'y qué significa cada argumento posicional',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<ToolRuntime>(
                        initialValue: _runtime,
                        decoration: const InputDecoration(
                          labelText: 'Runtime',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                          ),
                        ),
                        items: [
                          for (final runtime in ToolRuntime.values)
                            DropdownMenuItem(
                              value: runtime,
                              child: Text(runtime.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _runtime = value;
                            _codeController.language = _languageOf(value);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _timeoutController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText:
                              'Timeout en segundos (máx. '
                              '$kMaxToolTimeoutSeconds)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SecretMultiSelect(
                  selectedNames: _secretNames,
                  onChanged: (names) => setState(() => _secretNames = names),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.45,
                    ),
                    decoration: InputDecoration(
                      labelText:
                          'Código (recibe los argumentos como argv y '
                          'reporta por stdout/stderr)',
                      alignLabelWithHint: true,
                      // Fondo propio: el script se lee como un editor, no
                      // como un campo de formulario más.
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
