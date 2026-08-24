import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/knowledge/ui/widget/knowledge_base_multi_select.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/agent_profiles/ui/screen/agent_profile_form_screen.dart';
import 'package:keel_ui/src/modules/hooks/ui/widget/hook_multi_select.dart';
import 'package:keel_ui/src/modules/rules/ui/widget/rule_multi_select.dart';
import 'package:keel_ui/src/modules/projects/model/member_color.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/ui/widget/workflow_multi_select.dart';

Future<void> openProjectFormScreen(BuildContext context, {Project? initial}) {
  return showFormPanel<void>(
    context,
    child: ProjectFormScreen(initial: initial),
  );
}

class ProjectFormScreen extends StatefulWidget {
  const ProjectFormScreen({super.key, this.initial});

  final Project? initial;

  @override
  State<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<ProjectFormScreen> {
  late final _nameController = TextEditingController(
    text: widget.initial?.name,
  );
  late final _purposeController = TextEditingController(
    text: widget.initial?.purpose,
  );
  late final _workingDirectoryController = TextEditingController(
    text: widget.initial?.workingDirectory,
  );
  late List<String> _profileIds = [...?widget.initial?.profileIds];
  late List<String> _workflowNames = _initialWorkflowNames();
  late List<String> _ruleNames = [...?widget.initial?.ruleNames];
  late List<String> _hookNames = [...?widget.initial?.hookNames];
  late List<String> _knowledgeBaseNames = [
    ...?widget.initial?.knowledgeBaseNames,
  ];
  late bool _maintained = widget.initial?.maintained ?? true;
  String? _nameError;
  String? _formError;

  List<String> _initialWorkflowNames() {
    final ids = widget.initial?.workflowIds ?? const [];
    if (ids.isEmpty) return [];
    final workflows = WorkflowsService.instance.notifier.data.workflows;
    return ids
        .map((id) => workflows.where((w) => w.id == id).firstOrNull?.name)
        .whereType<String>()
        .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _purposeController.dispose();
    _workingDirectoryController.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    setState(() {
      _nameError = validateProjectName(value.trim());
      _formError = null;
    });
  }

  Future<void> _pickWorkingDirectory() async {
    final current = _workingDirectoryController.text.trim();
    final path = await getDirectoryPath(
      initialDirectory: current.isEmpty ? null : current,
    );
    if (path == null) return;
    setState(() => _workingDirectoryController.text = path);
  }

  /// El inverso de [_initialWorkflowNames]: el proyecto guarda ids, el
  /// formulario trabaja con nombres.
  List<String> _workflowNamesToIds(List<String> names) {
    final workflows = WorkflowsService.instance.notifier.data.workflows;
    return names
        .map((name) => workflows.where((w) => w.name == name).firstOrNull?.id)
        .whereType<String>()
        .toList();
  }

  void _toggleProfile(String id, bool selected) {
    setState(() {
      _profileIds = selected
          ? [..._profileIds, id]
          : _profileIds.where((entry) => entry != id).toList();
    });
  }

  void _submit() {
    final name = _nameController.text.trim();
    final nameError = validateProjectName(name);
    if (nameError != null) {
      setState(() => _nameError = nameError);
      return;
    }

    final workingDirectory = _workingDirectoryController.text.trim();
    if (workingDirectory.isEmpty) {
      setState(() => _formError = 'Elegí una carpeta de trabajo.');
      return;
    }

    final viewmodel = ProjectsService.instance.notifier;
    final initial = widget.initial;
    final workflowIds = _workflowNamesToIds(_workflowNames);
    final error = initial == null
        ? viewmodel.createProject(
            name: name,
            purpose: _purposeController.text,
            workingDirectory: workingDirectory,
            profileIds: _profileIds,
            workflowIds: workflowIds,
            ruleNames: _ruleNames,
            hookNames: _hookNames,
            knowledgeBaseNames: _knowledgeBaseNames,
            maintained: _maintained,
          )
        : viewmodel.updateProject(
            initial.id,
            name: name,
            purpose: _purposeController.text,
            workingDirectory: workingDirectory,
            profileIds: _profileIds,
            workflowIds: workflowIds,
            ruleNames: _ruleNames,
            hookNames: _hookNames,
            knowledgeBaseNames: _knowledgeBaseNames,
            maintained: _maintained,
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
        title: Text(isEditing ? 'Editar proyecto' : 'Registrar proyecto'),
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
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  onChanged: _onNameChanged,
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    errorText: _nameError,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _purposeController,
                  decoration: const InputDecoration(
                    labelText: 'Propósito',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _workingDirectoryController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Carpeta de trabajo',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: _pickWorkingDirectory,
                      child: const Text('Elegir…'),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    'Todos los agentes del proyecto trabajan sobre esta '
                    'carpeta.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _maintained,
                  onChanged: (value) => setState(() => _maintained = value),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Lo mantengo yo'),
                  subtitle: Text(
                    _maintained
                        ? 'Sus sesiones pueden escribir en el repo y puede '
                              'tomar requerimientos de otros proyectos.'
                        : 'Solo lectura: se puede consultar y puede pedirle '
                              'cosas a otros, pero no toma requerimientos '
                              'entrantes ni escribe en el repo.',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                const _SectionDivider('Ingredientes'),
                _ProjectMembersSelect(
                  selectedIds: _profileIds,
                  onToggle: _toggleProfile,
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    'El rol de cada agente permite al preflight asignar '
                    'responsables y consultas.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(height: 20),
                WorkflowMultiSelect(
                  selectedNames: _workflowNames,
                  onChanged: (names) => setState(() => _workflowNames = names),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    'Definen intención, contexto, gates y delegación. Sin '
                    'workflows, el proyecto no puede crear casos.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(height: 20),
                RuleMultiSelect(
                  selectedNames: _ruleNames,
                  onChanged: (names) => setState(() => _ruleNames = names),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    'Se suman a las reglas que ya trae el perfil de cada '
                    'agente.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(height: 20),
                HookMultiSelect(
                  selectedNames: _hookNames,
                  onChanged: (names) => setState(() => _hookNames = names),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    'Se suman a los del perfil de cada agente. A diferencia '
                    'de las reglas, estos no dependen de que el modelo los '
                    'respete.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(height: 20),
                KnowledgeBaseMultiSelect(
                  selectedNames: _knowledgeBaseNames,
                  onChanged: (names) =>
                      setState(() => _knowledgeBaseNames = names),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    'Sus miembros reciben el mapa de estas bases —dónde '
                    'están y qué hay— y las consultan cuando les hace falta. '
                    'Ningún otro proyecto las ve.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(height: 20),
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

class _ProjectMembersSelect extends StatelessWidget {
  const _ProjectMembersSelect({
    required this.selectedIds,
    required this.onToggle,
  });

  final List<String> selectedIds;
  final void Function(String id, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Agentes', style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            TextButton.icon(
              onPressed: () => openAgentProfileFormScreen(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Registrar agente'),
            ),
          ],
        ),
        ReactiveViewModelBuilder<AgentProfilesViewModel, AgentProfilesState>(
          viewmodel: AgentProfilesService.instance.notifier,
          build: (state, viewmodel, keep) {
            // Keel AI isn't a project collaborator: its turns run through
            // AgentsViewModel.sendMessage, not the project session runner, so
            // adding it here would just be an inert, non-functional member.
            final profiles = state.profiles
                .where((profile) => profile.name != kKeelAiHandle)
                .toList();
            if (profiles.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Todavía no registraste ningún agente.'),
              );
            }
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var index = 0; index < profiles.length; index++)
                  FilterChip(
                    avatar: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: memberColorFor(index),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    label: Text(profiles[index].name),
                    selected: selectedIds.contains(profiles[index].id),
                    onSelected: (selected) =>
                        onToggle(profiles[index].id, selected),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: scheme.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          ),
          Expanded(child: Divider(color: scheme.outlineVariant)),
        ],
      ),
    );
  }
}
