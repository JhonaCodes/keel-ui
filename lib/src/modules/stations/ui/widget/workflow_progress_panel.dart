import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/rules/ui/screen/rule_form_screen.dart';
import 'package:keel_ui/src/modules/rules/viewmodel/rules_viewmodel.dart';
import 'package:keel_ui/src/modules/stations/model/member_color.dart';
import 'package:keel_ui/src/modules/stations/model/station.dart';
import 'package:keel_ui/src/modules/stations/model/station_task.dart';
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

  AgentProfile? _ownerOf(WorkflowStep step) {
    final wanted = step.role.trim().toLowerCase();
    for (final member in members) {
      if (member.role.trim().toLowerCase() == wanted) return member;
    }
    return null;
  }

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

  Future<void> _addDocument(BuildContext context) async {
    final file = await openFile();
    if (file == null) return;
    StationsService.instance.notifier.addDocument(station.id, file.path);
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
              ownerIndex: members.indexWhere(
                (m) => m.id == _ownerOf(flow.steps[index])?.id,
              ),
              consulted: _consultedIn(index),
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
        _GroupHead(label: 'Documentos', onAdd: () => _addDocument(context)),
        for (final path in station.documentPaths)
          _BulletRow(
            label: path.split('/').last,
            filled: false,
            onRemove: () => StationsService.instance.notifier.removeDocument(
              station.id,
              path,
            ),
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
    required this.ownerIndex,
    required this.consulted,
  });

  final WorkflowStep step;
  final int index;
  final bool isLast;
  final _StepState state;
  final AgentProfile? owner;
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
                      ],
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
