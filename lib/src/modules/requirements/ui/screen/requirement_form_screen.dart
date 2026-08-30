import 'package:flutter/material.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/requirements/viewmodel/requirements_viewmodel.dart';

/// Abre el panel para escribir un requerimiento a mano.
///
/// Normalmente los abre un agente cuando se choca con algo que no está de su
/// lado. Esto es para cuando el que se choca sos vos.
Future<void> openRequirementFormPanel(BuildContext context) {
  return showFormPanel(context, child: const RequirementFormScreen());
}

class RequirementFormScreen extends StatefulWidget {
  const RequirementFormScreen({super.key});

  @override
  State<RequirementFormScreen> createState() => _RequirementFormScreenState();
}

class _RequirementFormScreenState extends State<RequirementFormScreen> {
  final _titleController = TextEditingController();
  final _needController = TextEditingController();
  final _contextController = TextEditingController();
  String? _fromId;
  String? _toId;
  bool _blocking = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _needController.dispose();
    _contextController.dispose();
    super.dispose();
  }

  void _submit() {
    final from = _fromId;
    final to = _toId;
    if (from == null || to == null) {
      setState(() => _error = 'Elegí de qué proyecto sale y a cuál va.');
      return;
    }
    final projects = ProjectsService.instance.notifier.data.projects;
    final target = projects.where((project) => project.id == to).firstOrNull;

    final result = RequirementsService.instance.notifier.open(
      fromProjectId: from,
      toProjectId: to,
      title: _titleController.text,
      need: _needController.text,
      context: _contextController.text,
      openedByHandle: '',
      openedInSessionId: '',
      blocking: _blocking,
      // Un proyecto que no mantenés no toma nada: el requerimiento igual se
      // anota, marcado, para que no se pierda el pedido.
      external: !(target?.maintained ?? true),
    );
    if (result.error != null) {
      setState(() => _error = result.error);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final projects = ProjectsService.instance.notifier.data.projects;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Abrir un requerimiento'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: FilledButton(onPressed: _submit, child: const Text('Abrir')),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProjectPicker(
                  label: 'Lo pide',
                  projects: projects,
                  value: _fromId,
                  onChanged: (id) => setState(() => _fromId = id),
                ),
                const SizedBox(height: 16),
                _ProjectPicker(
                  label: 'Se lo pide a',
                  projects: projects,
                  value: _toId,
                  onChanged: (id) => setState(() => _toId = id),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    'Tiene que ser un proyecto registrado. Un requerimiento '
                    'contra un repo que la app no conoce no lo puede tomar '
                    'nadie.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: t.labelRequirementTitle,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _needController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: t.labelRequirementNeed,
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _contextController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: t.labelRequirementContext,
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    'Es la mitad que le permite al otro lado decidir sin '
                    'preguntar tres veces.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _blocking,
                  onChanged: (value) => setState(() => _blocking = value),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Frena a quien lo pide'),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectPicker extends StatelessWidget {
  const _ProjectPicker({
    required this.label,
    required this.projects,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<Project> projects;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      items: [
        for (final project in projects)
          DropdownMenuItem(
            value: project.id,
            child: Text(
              '#${project.name}${project.maintained ? '' : '  🔒'}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
