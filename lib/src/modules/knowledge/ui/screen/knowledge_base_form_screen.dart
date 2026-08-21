import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/knowledge/model/knowledge_base.dart';
import 'package:keel_ui/src/modules/knowledge/viewmodel/knowledge_viewmodel.dart';

Future<void> openKnowledgeBaseFormScreen(
  BuildContext context, {
  KnowledgeBase? initial,
}) {
  return showFormPanel<void>(
    context,
    child: KnowledgeBaseFormScreen(initial: initial),
  );
}

class KnowledgeBaseFormScreen extends StatefulWidget {
  const KnowledgeBaseFormScreen({super.key, this.initial});

  final KnowledgeBase? initial;

  @override
  State<KnowledgeBaseFormScreen> createState() =>
      _KnowledgeBaseFormScreenState();
}

class _KnowledgeBaseFormScreenState extends State<KnowledgeBaseFormScreen> {
  late final _nameController = TextEditingController(
    text: widget.initial?.name,
  );
  late final _descriptionController = TextEditingController(
    text: widget.initial?.description,
  );
  late final _gitUrlController = TextEditingController(
    text: widget.initial?.gitUrl,
  );
  late final _gitBranchController = TextEditingController(
    text: widget.initial?.gitBranch,
  );
  late KnowledgeSource _source =
      widget.initial?.source ?? KnowledgeSource.local;
  late String _localPath = widget.initial?.localPath ?? '';
  String? _nameError;
  String? _formError;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _gitUrlController.dispose();
    _gitBranchController.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    setState(() {
      _nameError = validateKnowledgeBaseName(value.trim());
      _formError = null;
    });
  }

  Future<void> _pickFolder() async {
    final path = await getDirectoryPath(
      confirmButtonText: 'Usar esta carpeta',
    );
    if (path == null) return;
    setState(() {
      _localPath = path;
      _formError = null;
    });
  }

  void _submit() {
    final name = _nameController.text.trim();
    final nameError = validateKnowledgeBaseName(name);
    if (nameError != null) {
      setState(() => _nameError = nameError);
      return;
    }

    final viewmodel = KnowledgeService.instance.notifier;
    final initial = widget.initial;
    final error = initial == null
        ? viewmodel.createBase(
            name: name,
            description: _descriptionController.text,
            source: _source,
            gitUrl: _gitUrlController.text,
            gitBranch: _gitBranchController.text,
            localPath: _localPath,
          )
        : viewmodel.updateBase(
            initial.id,
            name: name,
            description: _descriptionController.text,
            source: _source,
            gitUrl: _gitUrlController.text,
            gitBranch: _gitBranchController.text,
            localPath: _localPath,
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
        title: Text(isEditing ? 'Editar base' : 'Nueva base de saber'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: FilledButton(
              onPressed: _submit,
              child: Text(isEditing ? 'Guardar' : 'Crear'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _nameController,
            onChanged: _onNameChanged,
            autofocus: !isEditing,
            decoration: InputDecoration(
              labelText: 'Nombre',
              hintText: 'NUI, CONNECT, KIWIO…',
              helperText: 'Con este nombre la citan las estaciones.',
              errorText: _nameError,
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Qué contesta esta base',
              hintText: 'Contratos de API, dominio y procesos de NUI Markets.',
              helperText:
                  'Es lo primero que lee un agente para decidir si buscar acá.',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Fuente', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<KnowledgeSource>(
            segments: [
              for (final source in KnowledgeSource.values)
                ButtonSegment(value: source, label: Text(source.label)),
            ],
            selected: {_source},
            onSelectionChanged: (selection) => setState(() {
              _source = selection.first;
              _formError = null;
            }),
          ),
          const SizedBox(height: 16),
          if (_source == KnowledgeSource.git) ...[
            TextField(
              controller: _gitUrlController,
              decoration: const InputDecoration(
                labelText: 'URL del repo',
                hintText: 'git@github.com:usuario/docs.git',
                helperText:
                    'Se clona a una carpeta propia dentro de la app y se '
                    'actualiza con pull.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _gitBranchController,
              decoration: const InputDecoration(
                labelText: 'Rama (opcional)',
                hintText: 'main',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
            ),
          ] else
            _FolderField(path: _localPath, onPick: _pickFolder),
          const SizedBox(height: 16),
          Text(
            'El INDEX.md de la raíz —o su README.md si no hay— se le '
            'entrega entero a los agentes como portada: qué hay acá y cuándo '
            'mirar cada cosa. El resto lo abren ellos cuando lo necesitan.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_formError != null) ...[
            const SizedBox(height: 16),
            Text(
              _formError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

/// La carpeta de una base local: se elige con el selector del sistema, no se
/// escribe a mano — una ruta tipeada mal solo se descubre cuando el árbol
/// aparece vacío.
class _FolderField extends StatelessWidget {
  const _FolderField({required this.path, required this.onPick});

  final String path;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.folder_open, size: 18),
              label: Text(path.isEmpty ? 'Elegir carpeta' : 'Cambiar carpeta'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                path.isEmpty ? 'Ninguna todavía' : path,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'La carpeta se lee donde está: no se copia nada.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
