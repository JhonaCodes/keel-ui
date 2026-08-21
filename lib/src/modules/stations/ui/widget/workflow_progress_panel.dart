import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/modules/agents/model/effort_level.dart';
import 'package:keel_ui/src/modules/rules/ui/screen/rule_form_screen.dart';
import 'package:keel_ui/src/modules/knowledge/ui/screen/knowledge_base_form_screen.dart';
import 'package:keel_ui/src/modules/knowledge/viewmodel/knowledge_viewmodel.dart';
import 'package:keel_ui/src/modules/rules/viewmodel/rules_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';
import 'package:keel_ui/src/modules/stations/model/member_color.dart';
import 'package:keel_ui/src/modules/stations/model/station.dart';
import 'package:keel_ui/src/modules/stations/model/station_task.dart';
import 'package:keel_ui/src/modules/stations/ui/widget/member_engine_panel.dart';
import 'package:keel_ui/src/modules/stations/viewmodel/stations_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

enum _StepState { done, current, pending }

/// The running workflow beside the thread: which step is on, who owns it, and
/// what is still coming. Progress lives here so the conversation stays a
/// conversation.
class WorkflowProgressPanel extends StatelessWidget {
  const WorkflowProgressPanel({
    super.key,
    required this.station,
    required this.task,
    required this.workflow,
    required this.members,
  });

  final Station station;
  final StationTask? task;
  final Workflow? workflow;
  final List<AgentProfile> members;

  AgentProfile? _ownerOf(WorkflowStep step) =>
      memberForRole(members, step.role);

  /// El dueño del paso con el motor que le toca en esta estación.
  AgentProfile? _engineOf(WorkflowStep step) {
    final owner = _ownerOf(step);
    return owner == null ? null : station.tuned(owner);
  }

  /// Cambia proveedor, modelo o esfuerzo del dueño del paso, solo acá.
  ///
  /// El ajuste es del MIEMBRO en esta estación, no del paso: si `flutter-expert`
  /// tiene tres pasos, los tres pasan a correr con lo que se elija. Que sea por
  /// miembro y no por paso es a propósito — el mismo agente pensando distinto
  /// según el paso es una diferencia que nadie puede sostener en la cabeza.
  Future<void> _tuneEngine(BuildContext context, WorkflowStep step) async {
    final owner = _ownerOf(step);
    if (owner == null) return;
    await openMemberEnginePanel(context, station: station, member: owner);
  }

  /// Cambia a quién le toca el paso [stepIndex], eligiendo entre los
  /// puestos que esta estación sí tiene.
  ///
  /// Esto edita el WORKFLOW, que es compartido: si `tdd` lo usan cuatro
  /// estaciones, el cambio vale para las cuatro. Es lo correcto cuando el
  /// paso nombra un agente puntual —eso lo ata a un stack— y se arregla
  /// poniéndole el puesto; por eso el diálogo lo dice antes de aplicar.
  Future<void> _assignStepRole(BuildContext context, int stepIndex) async {
    final flow = workflow;
    if (flow == null) return;

    final roles = <String>{
      for (final member in members)
        if (member.role.trim().isNotEmpty) member.role.trim(),
    }.toList()..sort();

    if (roles.isEmpty) {
      return;
    }

    final usadas = StationsService.instance.notifier.data.stations
        .where((entry) => entry.workflowIds.contains(flow.id))
        .length;

    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Quién hace "${flow.steps[stepIndex].title}"'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              usadas > 1
                  ? 'El paso pide el rol "${flow.steps[stepIndex].role}". '
                        'Elegí uno de los puestos de esta estación. El '
                        'workflow "${flow.name}" lo usan $usadas estaciones: '
                        'el cambio vale para todas, y en cada una lo toma su '
                        'propio miembro con ese rol.'
                  : 'El paso pide el rol "${flow.steps[stepIndex].role}". '
                        'Elegí uno de los puestos de esta estación.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          for (final role in roles)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(role),
              child: Text(
                '$role  —  ${members.where((m) => m.role.trim() == role).map((m) => '@${m.name}').join(', ')}',
              ),
            ),
        ],
      ),
    );
    if (picked == null) return;

    final steps = [
      for (var i = 0; i < flow.steps.length; i++)
        if (i == stepIndex)
          WorkflowStep(
            id: flow.steps[i].id,
            title: flow.steps[i].title,
            role: picked,
            instruction: flow.steps[i].instruction,
          )
        else
          flow.steps[i],
    ];
    WorkflowsService.instance.notifier.updateWorkflow(
      flow.id,
      name: flow.name,
      whenToApply: flow.whenToApply,
      steps: steps,
    );
  }

  /// Los puestos que esta estación sí puede cubrir. Un paso huérfano sin
  /// esta lista es un callejón: decir "sin agente para X" no dice qué poner
  /// en su lugar, y el rol correcto está a la vista de nadie.
  List<String> get _availableRoles => [
    for (final member in members)
      if (member.role.trim().isNotEmpty) '${member.role} (@${member.name})',
  ];

  /// Picks a registered rule and attaches it to the station, or jumps
  /// straight to registering a new one when the catalog is empty.
  Future<void> _addRule(BuildContext context) async {
    final rules = RulesService.instance.notifier.data.rules
        .where((rule) => !station.ruleNames.contains(rule.name))
        .toList();

    if (rules.isEmpty) {
      await openRuleFormScreen(context);
      return;
    }

    if (!context.mounted) return;
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Agregar regla'),
        children: [
          for (final rule in rules)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(rule.name),
              child: Text(rule.name),
            ),
        ],
      ),
    );
    if (picked == null) return;
    StationsService.instance.notifier.addRule(station.id, picked);
  }

  /// Suma una base de saber registrada a esta estación, o manda a crear una
  /// cuando todavía no hay ninguna disponible.
  Future<void> _addKnowledgeBase(BuildContext context) async {
    final bases = KnowledgeService.instance.notifier.data.bases
        .where((base) => !station.knowledgeBaseNames.contains(base.name))
        .toList();

    if (bases.isEmpty) {
      await openKnowledgeBaseFormScreen(context);
      return;
    }

    if (!context.mounted) return;
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Agregar base de saber'),
        children: [
          for (final base in bases)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(base.name),
              child: Text(base.name),
            ),
        ],
      ),
    );
    if (picked == null) return;
    StationsService.instance.notifier.addKnowledgeBase(station.id, picked);
  }

  /// Who this step consulted, read back from the thread: a message tagged
  /// with the step and carrying `consultOfProfileId` means its author was
  /// asked something while that step was running.
  String? _consultedIn(int stepIndex) {
    final open = task;
    if (open == null) return null;

    final names = <String>{};
    for (final message in open.messages) {
      if (message.stepIndex != stepIndex) continue;
      final answererId = message.authorProfileId;
      if (message.consultOfProfileId == null || answererId == null) continue;
      final answerer = members.where((m) => m.id == answererId).firstOrNull;
      if (answerer != null) names.add(answerer.name);
    }
    if (names.isEmpty) return null;
    return 'consultó a ${names.join(', ')}';
  }

  _StepState _stateOf(int index) {
    final open = task;
    if (open == null) return _StepState.pending;
    if (open.status == StationTaskStatus.finished) return _StepState.done;
    if (index < open.currentStepIndex) return _StepState.done;
    if (index == open.currentStepIndex) return _StepState.current;
    return _StepState.pending;
  }

  @override
  Widget build(BuildContext context) {
    final flow = workflow;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 14),
      children: [
        _GroupHead(label: flow == null ? 'Workflow' : 'Workflow en curso'),
        if (flow == null)
          const _PanelNote(
            'Esta estación no tiene un workflow activo. Agregá uno para que '
            'sepa cómo repartir el trabajo.',
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    flow.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (task != null)
                  Text(
                    '${(task!.currentStepIndex + 1).clamp(1, flow.steps.length)}'
                    ' de ${flow.steps.length}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
          for (var index = 0; index < flow.steps.length; index++)
            _StepRow(
              step: flow.steps[index],
              index: index,
              isLast: index == flow.steps.length - 1,
              state: _stateOf(index),
              owner: _ownerOf(flow.steps[index]),
              // El motor con el que ese miembro corre ACÁ, que puede no ser
              // el de su ficha. Es lo que se va a ejecutar, así que es lo
              // que se muestra.
              engine: _engineOf(flow.steps[index]),
              isTuned: station.memberTuning.containsKey(
                _ownerOf(flow.steps[index])?.id,
              ),
              ownerIndex: members.indexWhere(
                (m) => m.id == _ownerOf(flow.steps[index])?.id,
              ),
              consulted: _consultedIn(index),
              availableRoles: _availableRoles,
              onAssign: () => _assignStepRole(context, index),
              onTuneEngine: () => _tuneEngine(context, flow.steps[index]),
            ),
        ],
        _GroupHead(label: 'Reglas', onAdd: () => _addRule(context)),
        for (final rule in station.ruleNames)
          _BulletRow(
            label: rule,
            filled: true,
            onRemove: () =>
                StationsService.instance.notifier.removeRule(station.id, rule),
          ),
        _GroupHead(label: 'Saber', onAdd: () => _addKnowledgeBase(context)),
        for (final baseName in station.knowledgeBaseNames)
          _BulletRow(
            label: baseName,
            filled: true,
            onRemove: () => StationsService.instance.notifier
                .removeKnowledgeBase(station.id, baseName),
          ),
      ],
    );
  }
}

class _GroupHead extends StatelessWidget {
  const _GroupHead({required this.label, this.onAdd});

  final String label;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 14, onAdd == null ? 16 : 6, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                letterSpacing: 1.2,
                color: scheme.outline,
              ),
            ),
          ),
          if (onAdd != null)
            IconButton(
              tooltip: 'Agregar a esta estación',
              icon: const Icon(Icons.add, size: 15),
              constraints: const BoxConstraints.tightFor(width: 26, height: 26),
              padding: EdgeInsets.zero,
              onPressed: onAdd,
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.index,
    required this.isLast,
    required this.state,
    required this.owner,
    required this.engine,
    required this.isTuned,
    required this.ownerIndex,
    required this.consulted,
    required this.availableRoles,
    required this.onAssign,
    required this.onTuneEngine,
  });

  final WorkflowStep step;
  final List<String> availableRoles;
  final VoidCallback onAssign;
  final VoidCallback onTuneEngine;
  final int index;
  final bool isLast;
  final _StepState state;
  final AgentProfile? owner;

  /// [owner] con el motor de esta estación aplicado. Null cuando el paso está
  /// huérfano.
  final AgentProfile? engine;

  /// Si ese motor es un ajuste de esta estación y no el de su ficha.
  final bool isTuned;
  final int ownerIndex;
  final String? consulted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // The mockup distinguishes the three states by *shape*, not only colour:
    // done is a solid dot, the current step is a ring, pending is a faint
    // outline. Reading the panel at a glance depends on that difference.
    final beadFill = switch (state) {
      _StepState.done => scheme.tertiary,
      _StepState.current => Colors.transparent,
      _StepState.pending => Colors.transparent,
    };
    final beadBorder = switch (state) {
      _StepState.done => scheme.tertiary,
      _StepState.current => scheme.primary,
      _StepState.pending => scheme.outline,
    };
    final beadWidth = state == _StepState.current ? 2.5 : 1.5;

    final label = switch (state) {
      _StepState.done => 'listo',
      _StepState.current => 'ahora',
      _StepState.pending => '',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 11,
                  height: 11,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    color: beadFill,
                    shape: BoxShape.circle,
                    border: Border.all(color: beadBorder, width: beadWidth),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: state == _StepState.done
                          ? scheme.tertiary
                          : scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            step.title,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: state == _StepState.current
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: state == _StepState.pending
                                  ? scheme.outline
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                        if (label.isNotEmpty)
                          Text(
                            label,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: state == _StepState.done
                                  ? scheme.tertiary
                                  : scheme.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.smart_toy_outlined,
                          size: 15,
                          color: owner == null
                              ? scheme.error
                              : memberColorFor(ownerIndex),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: InkWell(
                            onTap: onAssign,
                            child: Tooltip(
                              message: owner != null
                                  ? '${owner!.role} — el paso pide '
                                        '"${step.role}". Click para cambiarlo.'
                                  : 'Ningún miembro de esta estación tiene el '
                                        'rol "${step.role}".\n'
                                        'Puestos disponibles acá:\n'
                                        '${availableRoles.isEmpty ? '(la estación no tiene miembros)' : availableRoles.join('\n')}\n'
                                        'Click para elegir uno.',
                              waitDuration: const Duration(milliseconds: 400),
                              child: Text(
                                owner?.name ?? 'sin agente para "${step.role}"',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: owner == null
                                      ? scheme.error
                                      : scheme.outline,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (engine != null)
                      _EngineLine(
                        engine: engine!,
                        isTuned: isTuned,
                        onTap: onTuneEngine,
                      ),
                    if (consulted != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          consulted!,
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: scheme.outline,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Con qué motor corre el dueño del paso: modelo, esfuerzo y —cuando es un
/// ajuste de esta estación— un punto que lo marca.
///
/// Va a la vista y no detrás de un tooltip porque es la línea que explica el
/// costo: un paso en Opus vale varias veces uno en Sonnet, y eso no se nota
/// hasta que llega la factura.
class _EngineLine extends StatelessWidget {
  const _EngineLine({
    required this.engine,
    required this.isTuned,
    required this.onTap,
  });

  final AgentProfile engine;
  final bool isTuned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Codex resuelve el esfuerzo en su propia config: nombrarlo acá sería
    // decir que se aplica algo que el turno nunca manda.
    final texto = engine.provider == AgentProvider.codex
        ? modelLabelFor(engine.provider, engine.model)
        : '${modelLabelFor(engine.provider, engine.model)} · '
              '${effortLabel(engine.effort)}';

    return Padding(
      padding: const EdgeInsets.only(top: 3, left: 21),
      child: InkWell(
        onTap: onTap,
        child: Tooltip(
          message: isTuned
              ? 'Motor fijado para esta estación. Click para cambiarlo.'
              : 'El motor de su ficha, igual que en todas partes. Click para '
                    'cambiarlo solo acá.',
          waitDuration: const Duration(milliseconds: 400),
          child: Row(
            children: [
              if (isTuned) ...[
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  texto,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: isTuned ? scheme.primary : scheme.outlineVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A rule or a document: the mockup marks them with a small accent square —
/// solid for rules, hollow for documents — not with a Material icon.
class _BulletRow extends StatefulWidget {
  const _BulletRow({
    required this.label,
    required this.filled,
    required this.onRemove,
  });

  final String label;
  final bool filled;
  final VoidCallback onRemove;

  @override
  State<_BulletRow> createState() => _BulletRowState();
}

class _BulletRowState extends State<_BulletRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 3, 6, 3),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: widget.filled ? scheme.primary : Colors.transparent,
                border: Border.all(color: scheme.primary, width: 1.2),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            SizedBox(
              width: 26,
              height: 26,
              child: _hovering
                  ? IconButton(
                      tooltip: 'Quitar de esta estación',
                      icon: const Icon(Icons.close, size: 13),
                      constraints: const BoxConstraints.tightFor(
                        width: 26,
                        height: 26,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: widget.onRemove,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelNote extends StatelessWidget {
  const _PanelNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
