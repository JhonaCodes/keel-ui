import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/skills/ui/widget/skill_multi_select.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';

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
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _when = TextEditingController(text: widget.initial?.whenToApply);
  late final _rules = TextEditingController(
    text: widget.initial?.policy.requiredRuleNames.join(', ') ?? '',
  );
  late final _knowledge = TextEditingController(
    text: widget.initial?.policy.requiredKnowledgeBaseNames.join(', ') ?? '',
  );
  late WorkflowKind _kind = widget.initial?.kind ?? WorkflowKind.bug;
  late String _ownerRole = widget.initial?.policy.resolutionRole ?? '';
  late int _maxReplans = widget.initial?.policy.maxReplans ?? 2;
  late int _maxSubagents = widget.initial?.policy.maxSubagents ?? 1;
  late int _maxReviewCycles = widget.initial?.policy.maxReviewCycles ?? 4;
  late int _idleTimeoutMinutes =
      widget.initial?.policy.idleTimeoutMinutes ?? kDefaultIdleTimeoutMinutes;
  late int _nodeTimeoutMinutes =
      widget.initial?.policy.nodeTimeoutMinutes ?? kDefaultNodeTimeoutMinutes;
  late int _maxSessionCostUsd =
      widget.initial?.policy.maxSessionCostUsd.round() ??
      kDefaultMaxSessionCostUsd.round();
  late List<String> _skills = [...?widget.initial?.policy.requiredSkillNames];
  late List<WorkflowCapability> _capabilities = [
    ...(widget.initial?.capabilities.isNotEmpty == true
        ? widget.initial!.capabilities
        : defaultWorkflowCapabilities(_kind, _ownerRole)),
  ];
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _when.dispose();
    _rules.dispose();
    _knowledge.dispose();
    super.dispose();
  }

  List<String> _names(TextEditingController controller) => controller.text
      .split(',')
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .toSet()
      .toList();

  void _submit() {
    final name = _name.text.trim();
    final nameError = validateWorkflowName(name);
    if (nameError != null) {
      setState(() => _error = nameError);
      return;
    }
    final capabilitiesError = validateWorkflowCapabilities(_capabilities);
    if (capabilitiesError != null) {
      setState(() => _error = capabilitiesError);
      return;
    }
    final policy = WorkflowPolicy(
      resolutionRole: _ownerRole,
      requiredSkillNames: _skills,
      requiredRuleNames: _names(_rules),
      requiredKnowledgeBaseNames: _names(_knowledge),
      qualityGates: _kind == WorkflowKind.migration
          ? WorkflowQualityGate.values
          : const [
              WorkflowQualityGate.analysis,
              WorkflowQualityGate.focusedTests,
              WorkflowQualityGate.regression,
            ],
      maxReplans: _maxReplans,
      maxSubagents: _maxSubagents,
      maxReviewCycles: _maxReviewCycles,
      idleTimeoutMinutes: _idleTimeoutMinutes,
      nodeTimeoutMinutes: _nodeTimeoutMinutes,
      maxSessionCostUsd: _maxSessionCostUsd.toDouble(),
    );
    final workflows = WorkflowsService.instance.notifier;
    final initial = widget.initial;
    final error = initial == null
        ? workflows.createWorkflow(
            name: name,
            whenToApply: _when.text,
            skillNames: _skills,
            kind: _kind,
            policy: policy,
            capabilities: _capabilities,
          )
        : workflows.updateWorkflow(
            initial.id,
            name: name,
            whenToApply: _when.text,
            skillNames: _skills,
            kind: _kind,
            policy: policy,
            capabilities: _capabilities,
          );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Editar workflow' : 'Crear workflow'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: FilledButton(
              onPressed: _submit,
              child: Text(editing ? 'Guardar' : 'Crear'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _when,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.formLabelWorkflowIntent,
              helperText: AppLocalizations.of(context)!.formDescriptionWorkflowEngine,
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<WorkflowKind>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Tipo de caso'),
            items: [
              for (final kind in WorkflowKind.values)
                DropdownMenuItem(value: kind, child: Text(_kindLabel(kind, AppLocalizations.of(context)!))),
            ],
            onChanged: (value) => setState(() {
              _kind = value!;
              if (widget.initial == null) {
                _capabilities = defaultWorkflowCapabilities(
                  _kind,
                  _ownerRole,
                  l10n: AppLocalizations.of(context),
                );
              }
            }),
          ),
          const SizedBox(height: 20),
          _ResolutionRoleField(
            value: _ownerRole,
            onChanged: (value) => setState(() {
              final previous = _ownerRole.isEmpty ? '*' : _ownerRole;
              _ownerRole = value;
              final next = value.isEmpty ? '*' : value;
              _capabilities = [
                for (final capability in _capabilities)
                  capability.role == previous
                      ? capability.copyWith(role: next)
                      : capability,
              ];
            }),
          ),
          const SizedBox(height: 20),
          _CapabilitiesEditor(
            capabilities: _capabilities,
            onChanged: (value) => setState(() => _capabilities = value),
          ),
          const SizedBox(height: 20),
          const Text('Contexto obligatorio'),
          const SizedBox(height: 8),
          SkillMultiSelect(
            selectedNames: _skills,
            onChanged: (value) => setState(() => _skills = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rules,
            decoration: const InputDecoration(
              labelText: 'Reglas requeridas',
              helperText: 'Nombres separados por coma.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _knowledge,
            decoration: const InputDecoration(
              labelText: 'Bases de conocimiento requeridas',
              helperText: 'Nombres separados por coma.',
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context)!.labelMaxReplansLimit(_maxReplans),
          ),
          Slider(
            value: _maxReplans.toDouble(),
            min: 0,
            max: 2,
            divisions: 2,
            label: '$_maxReplans',
            onChanged: (value) => setState(() => _maxReplans = value.round()),
          ),
          Text(
            AppLocalizations.of(
              context,
            )!.labelMaxSubagentsLimit(_maxSubagents),
          ),
          Slider(
            value: _maxSubagents.toDouble(),
            min: 0,
            max: kMaxSubagentsPerNode.toDouble(),
            divisions: kMaxSubagentsPerNode,
            label: '$_maxSubagents',
            onChanged: (value) => setState(() => _maxSubagents = value.round()),
          ),
          Text(
            AppLocalizations.of(
              context,
            )!.labelMaxReviewCyclesLimit(_maxReviewCycles),
          ),
          Slider(
            value: _maxReviewCycles.toDouble(),
            min: 1,
            max: 4,
            divisions: 3,
            label: '$_maxReviewCycles',
            onChanged: (value) =>
                setState(() => _maxReviewCycles = value.round()),
          ),
          Text(
            AppLocalizations.of(
              context,
            ).labelIdleTimeoutLimit(_idleTimeoutMinutes),
          ),
          Slider(
            value: _idleTimeoutMinutes.toDouble(),
            min: 1,
            max: 60,
            divisions: 59,
            label: '$_idleTimeoutMinutes',
            onChanged: (value) =>
                setState(() => _idleTimeoutMinutes = value.round()),
          ),
          Text(
            AppLocalizations.of(
              context,
            ).labelNodeTimeoutLimit(_nodeTimeoutMinutes),
          ),
          Slider(
            value: _nodeTimeoutMinutes.toDouble(),
            min: 5,
            max: 240,
            divisions: 47,
            label: '$_nodeTimeoutMinutes',
            onChanged: (value) =>
                setState(() => _nodeTimeoutMinutes = value.round()),
          ),
          Text(
            AppLocalizations.of(
              context,
            ).labelSessionCostLimit(_maxSessionCostUsd),
          ),
          Slider(
            value: _maxSessionCostUsd.toDouble(),
            min: 0,
            max: 200,
            divisions: 40,
            label: _maxSessionCostUsd == 0 ? '∞' : '$_maxSessionCostUsd',
            onChanged: (value) =>
                setState(() => _maxSessionCostUsd = value.round()),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _CapabilitiesEditor extends StatelessWidget {
  const _CapabilitiesEditor({
    required this.capabilities,
    required this.onChanged,
  });

  final List<WorkflowCapability> capabilities;
  final ValueChanged<List<WorkflowCapability>> onChanged;

  void _replace(WorkflowCapability capability) {
    onChanged([
      for (final entry in capabilities)
        entry.id == capability.id ? capability : entry,
    ]);
  }

  void _add() {
    var suffix = capabilities.length + 1;
    var id = 'capability-$suffix';
    while (capabilities.any((entry) => entry.id == id)) {
      suffix++;
      id = 'capability-$suffix';
    }
    onChanged([
      ...capabilities,
      WorkflowCapability(
        id: id,
        title: 'Nueva capacidad',
        instruction: '',
        role: '*',
        activation: WorkflowCapabilityActivation.optional,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Capacidades adaptativas')),
            TextButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Agregar'),
            ),
          ],
        ),
        Text(
          'Se muestran como pasos en el panel, pero solo las requeridas '
          'entran al grafo inicial. Las opcionales se activan por evidencia.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        for (final capability in capabilities)
          _CapabilityEditorTile(
            key: ValueKey(capability.id),
            capability: capability,
            availableIds: [for (final entry in capabilities) entry.id],
            onChanged: _replace,
            onDelete: capabilities.length == 1
                ? null
                : () => onChanged(
                    capabilities
                        .where((entry) => entry.id != capability.id)
                        .map(
                          (entry) => entry.copyWith(
                            dependencyIds: entry.dependencyIds
                                .where((id) => id != capability.id)
                                .toList(),
                          ),
                        )
                        .toList(),
                  ),
          ),
      ],
    );
  }
}

class _CapabilityEditorTile extends StatefulWidget {
  const _CapabilityEditorTile({
    super.key,
    required this.capability,
    required this.availableIds,
    required this.onChanged,
    required this.onDelete,
  });

  final WorkflowCapability capability;
  final List<String> availableIds;
  final ValueChanged<WorkflowCapability> onChanged;
  final VoidCallback? onDelete;

  @override
  State<_CapabilityEditorTile> createState() => _CapabilityEditorTileState();
}

class _CapabilityEditorTileState extends State<_CapabilityEditorTile> {
  late final TextEditingController _title = TextEditingController(
    text: widget.capability.title,
  );
  late final TextEditingController _instruction = TextEditingController(
    text: widget.capability.instruction,
  );
  late final TextEditingController _role = TextEditingController(
    text: widget.capability.role,
  );
  late final TextEditingController _dependencies = TextEditingController(
    text: widget.capability.dependencyIds.join(', '),
  );
  late final TextEditingController _parent = TextEditingController(
    text: widget.capability.parentCapabilityId,
  );
  late final TextEditingController _maxTurns = TextEditingController(
    text: widget.capability.maxAgenticTurns == 0
        ? ''
        : '${widget.capability.maxAgenticTurns}',
  );
  late final TextEditingController _outputContract = TextEditingController(
    text: widget.capability.outputContract,
  );

  @override
  void dispose() {
    _title.dispose();
    _instruction.dispose();
    _role.dispose();
    _dependencies.dispose();
    _parent.dispose();
    _maxTurns.dispose();
    _outputContract.dispose();
    super.dispose();
  }

  void _emit({
    WorkflowCapabilityActivation? activation,
    WorkflowExecutor? executor,
    bool? readOnly,
    bool? requiresIndependentOwner,
    bool? approvalRequired,
  }) {
    final dependencies = _dependencies.text
        .split(',')
        .map((value) => value.trim())
        .where(
          (value) =>
              value.isNotEmpty &&
              value != widget.capability.id &&
              widget.availableIds.contains(value),
        )
        .toSet()
        .toList();
    widget.onChanged(
      widget.capability.copyWith(
        title: _title.text.trim(),
        instruction: _instruction.text.trim(),
        role: _role.text.trim().isEmpty ? '*' : _role.text.trim(),
        dependencyIds: dependencies,
        activation: activation,
        executor: executor,
        parentCapabilityId: _parent.text.trim(),
        maxAgenticTurns: int.tryParse(_maxTurns.text.trim()) ?? 0,
        readOnly: readOnly,
        outputContract: _outputContract.text.trim(),
        requiresIndependentOwner: requiresIndependentOwner,
        approvalRequired: approvalRequired,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: Text(_title.text),
        subtitle: Text(
          '${widget.capability.id} · ${widget.capability.activation.name}',
        ),
        trailing: widget.onDelete == null
            ? null
            : IconButton(
                tooltip: 'Eliminar capacidad',
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          TextField(
            controller: _title,
            onChanged: (_) {
              setState(() {});
              _emit();
            },
            decoration: InputDecoration(labelText: AppLocalizations.of(context)!.formLabelWorkflowTitle),
          ),
          TextField(
            controller: _instruction,
            onChanged: (_) => _emit(),
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(labelText: AppLocalizations.of(context)!.formLabelWorkflowInstruction),
          ),
          TextField(
            controller: _role,
            onChanged: (_) => _emit(),
            decoration: const InputDecoration(
              labelText: 'Rol o perfil destino (@auditor)',
            ),
          ),
          TextField(
            controller: _dependencies,
            onChanged: (_) => _emit(),
            decoration: const InputDecoration(
              labelText: 'Dependencias por ID',
              helperText: 'Separadas por coma; no definen un orden global.',
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<WorkflowCapabilityActivation>(
            initialValue: widget.capability.activation,
            decoration: InputDecoration(labelText: AppLocalizations.of(context)!.formLabelWorkflowActivation),
            items: const [
              DropdownMenuItem(
                value: WorkflowCapabilityActivation.required,
                child: Text('Requerida'),
              ),
              DropdownMenuItem(
                value: WorkflowCapabilityActivation.optional,
                child: Text('Opcional'),
              ),
            ],
            onChanged: (value) => _emit(activation: value),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<WorkflowExecutor>(
            initialValue: widget.capability.executor,
            decoration: InputDecoration(labelText: AppLocalizations.of(context)!.formLabelWorkflowExecution),
            items: [
              DropdownMenuItem(
                value: WorkflowExecutor.newSession,
                child: Text(AppLocalizations.of(context)!.optionNewSession),
              ),
              DropdownMenuItem(
                value: WorkflowExecutor.resumeParent,
                child: Text(AppLocalizations.of(context)!.optionResumeParentSession),
              ),
              DropdownMenuItem(
                value: WorkflowExecutor.providerSubagent,
                child: Text('Subagente del proveedor'),
              ),
              DropdownMenuItem(
                value: WorkflowExecutor.manualApproval,
                child: Text(AppLocalizations.of(context)!.optionManualApproval),
              ),
            ],
            onChanged: (value) => _emit(executor: value),
          ),
          if (widget.capability.executor == WorkflowExecutor.resumeParent ||
              widget.capability.executor == WorkflowExecutor.providerSubagent)
            TextField(
              controller: _parent,
              onChanged: (_) => _emit(),
              decoration: InputDecoration(
                labelText: 'ID del paso padre',
                helperText: AppLocalizations.of(context)!.formDescriptionParentSessionKept,
              ),
            ),
          TextField(
            controller: _maxTurns,
            keyboardType: TextInputType.number,
            onChanged: (_) => _emit(),
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.formLabelMaxAgenticTurns,
              helperText: AppLocalizations.of(context)!.formDescriptionMaxAgenticTurns,
            ),
          ),
          TextField(
            controller: _outputContract,
            onChanged: (_) => _emit(),
            decoration: const InputDecoration(
              labelText: 'Contrato de salida',
              helperText: 'Ejemplo: audit-feedback.',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Solo lectura'),
            subtitle: const Text('Planificadores y auditores no escriben.'),
            value: widget.capability.readOnly,
            onChanged: (value) => _emit(readOnly: value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Requiere agente independiente'),
            subtitle: const Text(
              'El dueño debe ser distinto de quienes produjeron sus dependencias.',
            ),
            value: widget.capability.requiresIndependentOwner,
            onChanged: (value) => _emit(requiresIndependentOwner: value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pide tu aprobación antes de correr'),
            subtitle: const Text(
              'El paso queda esperándote hasta que lo aprobás (p. ej. publicar).',
            ),
            value: widget.capability.approvalRequired,
            onChanged: (value) => _emit(approvalRequired: value),
          ),
        ],
      ),
    );
  }
}

class _ResolutionRoleField extends StatelessWidget {
  const _ResolutionRoleField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<AgentProfilesViewModel, AgentProfilesState>(
      viewmodel: AgentProfilesService.instance.notifier,
      build: (state, viewmodel, keep) {
        final roles = <String>{
          for (final profile in state.profiles)
            if (profile.role.trim().isNotEmpty) profile.role.trim(),
          if (value.isNotEmpty) value,
        }.toList()..sort();
        return DropdownButtonFormField<String>(
          initialValue: value.isEmpty ? null : value,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.formLabelWorkflowResponsible,
            helperText: AppLocalizations.of(context)!.formDescriptionResponsible,
          ),
          items: [
            const DropdownMenuItem(value: '', child: Text('Cualquier miembro')),
            for (final role in roles)
              DropdownMenuItem(value: role, child: Text(role)),
          ],
          onChanged: (role) => onChanged(role ?? ''),
        );
      },
    );
  }
}

String _kindLabel(WorkflowKind kind, AppLocalizations? t) => switch (kind) {
  WorkflowKind.general => 'General',
  WorkflowKind.bug => 'Bug',
  WorkflowKind.migration => t?.workflowKindMigration ?? 'Migración',
  WorkflowKind.roadmap => 'Formato de tareas',
};
