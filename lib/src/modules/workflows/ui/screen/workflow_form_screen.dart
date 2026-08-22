import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/model/agent_icon_colors.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';
import 'package:keel_ui/src/shared/shared.dart';

/// A stable, distinct accent per step position — there's no registered
/// entity a step's free-text role can be colored from at authoring time, so
/// this reuses the same palette agent icons draw from, keyed by the step's
/// index in the list.
Color _stepColor(int index) {
  if (index < kAgentIconColorPalette.length) {
    return kAgentIconColorPalette[index];
  }
  return nextAgentIconColor(kAgentIconColorPalette.take(index).toList());
}

Future<void> openWorkflowFormScreen(BuildContext context, {Workflow? initial}) {
  return showFormPanel<void>(
    context,
    child: WorkflowFormScreen(initial: initial),
  );
}

class WorkflowFormScreen extends StatefulWidget {
  const WorkflowFormScreen({super.key, this.initial});

  final Workflow? initial;

  @override
  State<WorkflowFormScreen> createState() => _WorkflowFormScreenState();
}

class _WorkflowFormScreenState extends State<WorkflowFormScreen> {
  late final _nameController = TextEditingController(
    text: widget.initial?.name,
  );
  late final _whenToApplyController = TextEditingController(
    text: widget.initial?.whenToApply,
  );
  late List<WorkflowStep> _steps = [...?widget.initial?.steps];
  String? _nameError;
  String? _formError;

  @override
  void dispose() {
    _nameController.dispose();
    _whenToApplyController.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    setState(() {
      _nameError = validateWorkflowName(value.trim());
      _formError = null;
    });
  }

  void _addStep() {
    setState(() {
      _steps = [
        ..._steps,
        WorkflowStep(
          id: generateUuidV4(),
          title: '',
          role: '',
          instruction: '',
        ),
      ];
    });
  }

  void _removeStep(String id) {
    setState(() {
      _steps = _steps.where((step) => step.id != id).toList();
    });
  }

  void _updateStep(WorkflowStep updated) {
    setState(() {
      _steps = _steps
          .map((step) => step.id == updated.id ? updated : step)
          .toList();
    });
  }

  void _reorderSteps(int oldIndex, int newIndex) {
    setState(() {
      final steps = [..._steps];
      final step = steps.removeAt(oldIndex);
      steps.insert(newIndex, step);
      _steps = steps;
    });
  }

  void _submit() {
    final name = _nameController.text.trim();
    final nameError = validateWorkflowName(name);
    if (nameError != null) {
      setState(() => _nameError = nameError);
      return;
    }

    final viewmodel = WorkflowsService.instance.notifier;
    final initial = widget.initial;
    final error = initial == null
        ? viewmodel.createWorkflow(
            name: name,
            whenToApply: _whenToApplyController.text,
            steps: _steps,
          )
        : viewmodel.updateWorkflow(
            initial.id,
            name: name,
            whenToApply: _whenToApplyController.text,
            steps: _steps,
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
        title: Text(isEditing ? 'Editar workflow' : 'Registrar workflow'),
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
                    labelText: 'Nombre',
                    errorText: _nameError,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _whenToApplyController,
                  decoration: const InputDecoration(
                    labelText: 'Cuándo se aplica',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    'Así el proyecto sabe cuál de sus workflows corresponde '
                    'a lo que pediste.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                const _SectionDivider('Pasos'),
                Expanded(
                  child: _steps.isEmpty
                      ? const Center(
                          child: Text('Todavía no agregaste ningún paso.'),
                        )
                      : ReorderableListView(
                          onReorderItem: _reorderSteps,
                          children: [
                            for (var index = 0; index < _steps.length; index++)
                              _WorkflowStepEditor(
                                key: ValueKey(_steps[index].id),
                                step: _steps[index],
                                index: index,
                                onChanged: _updateStep,
                                onRemove: () => _removeStep(_steps[index].id),
                              ),
                          ],
                        ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('Agregar paso'),
                    onPressed: _addStep,
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

class _WorkflowStepEditor extends StatefulWidget {
  const _WorkflowStepEditor({
    required Key key,
    required this.step,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  }) : super(key: key);

  final WorkflowStep step;
  final int index;
  final ValueChanged<WorkflowStep> onChanged;
  final VoidCallback onRemove;

  @override
  State<_WorkflowStepEditor> createState() => _WorkflowStepEditorState();
}

class _WorkflowStepEditorState extends State<_WorkflowStepEditor> {
  late final _titleController = TextEditingController(text: widget.step.title);
  late String _role = widget.step.role;
  late final _instructionController = TextEditingController(
    text: widget.step.instruction,
  );

  @override
  void dispose() {
    _titleController.dispose();
    _instructionController.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged(
      widget.step.copyWith(
        title: _titleController.text,
        role: _role,
        instruction: _instructionController.text,
      ),
    );
  }

  void _onRoleChanged(String role) {
    setState(() => _role = role);
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final color = _stepColor(widget.index);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.drag_handle),
                const SizedBox(width: 8),
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${widget.index + 1}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    onChanged: (_) => _notify(),
                    decoration: const InputDecoration(
                      labelText: 'Título del paso',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Eliminar paso',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: _RoleDropdown(
                value: _role,
                color: color,
                onChanged: _onRoleChanged,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _instructionController,
              onChanged: (_) => _notify(),
              minLines: 2,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Instrucción',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A step's role must match an actual registered agent's role at runtime —
/// see `WorkflowStep.role`'s doc comment — so this is a closed pick from the
/// roles currently registered on `AgentProfile`s, not free text: a typo here
/// ("Analizer" vs "Analista") is exactly what used to silently produce
/// "sin agente para X" when the field ran on independently-typed strings.
/// Closed while editing means opening the dropdown and choosing one (the
/// current value shows checked); collapsed it reads as plain text, same as
/// any other Material dropdown field.
class _RoleDropdown extends StatelessWidget {
  const _RoleDropdown({
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String value;
  final Color color;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<AgentProfilesViewModel, AgentProfilesState>(
      viewmodel: AgentProfilesService.instance.notifier,
      build: (state, viewmodel, keep) {
        final registeredRoles = <String>{
          for (final profile in state.profiles)
            if (profile.role.trim().isNotEmpty) profile.role,
        };
        // Keeps a stale/legacy value selectable (never silently dropped by
        // opening the editor) without letting new selections drift away
        // from an actual registered agent's role.
        final options = {
          ...registeredRoles,
          if (value.trim().isNotEmpty) value,
        }.toList()..sort();

        if (options.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'Registra un agente con un rol para poder asignarlo a un paso.',
              style: TextStyle(fontSize: 11),
            ),
          );
        }

        return Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: DropdownButtonFormField<String>(
                  initialValue: value.trim().isEmpty ? null : value,
                  isDense: true,
                  // Sin esto el botón se dimensiona por su ítem más ancho y
                  // se sale de la píldora: un rol escrito en prosa ("del
                  // objetivo difuso a tareas atómicas") pide bastante más de
                  // los 280 puntos que mide.
                  isExpanded: true,
                  hint: const Text(
                    'Rol',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: const InputDecoration(
                    isDense: true,
                    isCollapsed: true,
                    border: InputBorder.none,
                  ),
                  items: [
                    for (final role in options)
                      DropdownMenuItem(value: role, child: Text(role)),
                  ],
                  // El desplegable puede mostrar el rol entero; el campo
                  // cerrado vive en una píldora angosta y lo corta.
                  selectedItemBuilder: (context) => [
                    for (final role in options)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          role,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (role) {
                    if (role != null) onChanged(role);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
