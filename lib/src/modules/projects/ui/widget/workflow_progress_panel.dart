import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/modules/agents/model/effort_level.dart';
import 'package:keel_ui/src/modules/knowledge/ui/screen/knowledge_base_form_screen.dart';
import 'package:keel_ui/src/modules/knowledge/viewmodel/knowledge_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/model/member_color.dart';
import 'package:keel_ui/src/modules/projects/model/migration_coverage.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_case.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_finding.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/work_node.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/member_engine_panel.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/rules/ui/screen/rule_form_screen.dart';
import 'package:keel_ui/src/modules/rules/viewmodel/rules_viewmodel.dart';
import 'package:keel_ui/src/modules/secrets/ui/widget/provider_credential_card.dart';
import 'package:keel_ui/src/modules/projects/service/resolution_engine.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';

enum _CapabilityState {
  done,
  current,
  pending,
  blocked,
  available,
  notRequired,
}

/// The 272 px workflow rail from the product mockup, backed by adaptive
/// capabilities and persisted graph nodes rather than positional steps.
class WorkflowProgressPanel extends StatelessWidget {
  const WorkflowProgressPanel({
    super.key,
    required this.project,
    required this.session,
    required this.workflow,
    required this.members,
  });

  final Project project;
  final Session? session;
  final Workflow? workflow;
  final List<AgentProfile> members;

  List<WorkflowCapability> _capabilitiesOf(AppLocalizations t) {
    final flow = workflow;
    if (flow == null) return const [];
    // The default titles localize only when l10n is handed in; the panel has a
    // context, so it hands it in instead of falling back to English.
    return flow.capabilities.isEmpty
        ? defaultWorkflowCapabilities(
            flow.kind,
            flow.policy.resolutionRole,
            l10n: t,
          )
        : flow.capabilities;
  }

  WorkNode? _nodeOf(String capabilityId) {
    final nodes = session?.resolutionCase?.nodes ?? const <WorkNode>[];
    final direct = nodes.where((node) => node.id == capabilityId).firstOrNull;
    if (direct != null) return direct;
    // Una sesión guardada ANTES del renombre tiene el nodo con el id viejo.
    // Sin este puente su nodo en curso no aparece en ningún lado y la
    // capacidad nueva se dibuja como pendiente, con el trabajo corriendo.
    final legacy = kLegacyCapabilityIds[capabilityId];
    if (legacy == null) return null;
    return nodes.where((node) => node.id == legacy).firstOrNull;
  }

  AgentProfile? _ownerOf(WorkflowCapability capability) {
    final node = _nodeOf(capability.id);
    final profileId = node?.ownerProfileId.isNotEmpty == true
        ? node!.ownerProfileId
        : workflow == null
        ? null
        : project.assignedProfileId(workflow!.id, capability.id);
    if (profileId != null) {
      final exact = members
          .where((member) => member.id == profileId)
          .firstOrNull;
      if (exact != null) return exact;
    }
    return memberForRole(members, node?.ownerRole ?? capability.role);
  }

  AgentProfile? _engineOf(WorkflowCapability capability) {
    final owner = _ownerOf(capability);
    return owner == null ? null : project.tuned(owner);
  }

  WorkflowCapability _displayCapability(
    AppLocalizations t,
    WorkflowCapability capability,
  ) {
    final node = _nodeOf(capability.id);
    if (node == null || node.title.isNotEmpty) return capability;
    final title = switch (node.kind) {
      WorkNodeKind.triage => t.nodeKindTriage,
      WorkNodeKind.impact => t.nodeKindImpact,
      WorkNodeKind.implementation => t.nodeKindImplementation,
      WorkNodeKind.verification => t.nodeKindVerification,
      WorkNodeKind.custom => capability.title,
    };
    return capability.copyWith(title: title);
  }

  _CapabilityState _stateOf(WorkflowCapability capability) {
    final node = _nodeOf(capability.id);
    if (node == null) {
      if (capability.activation == WorkflowCapabilityActivation.optional) {
        return session?.resolutionCase?.status == ResolutionCaseStatus.completed
            ? _CapabilityState.notRequired
            : _CapabilityState.available;
      }
      return _CapabilityState.pending;
    }
    return switch (node.status) {
      WorkNodeStatus.done => _CapabilityState.done,
      WorkNodeStatus.running => _CapabilityState.current,
      WorkNodeStatus.pending => _CapabilityState.pending,
      WorkNodeStatus.paused ||
      WorkNodeStatus.blocked => _CapabilityState.blocked,
    };
  }

  bool _canAssign(WorkflowCapability capability) {
    final status = _nodeOf(capability.id)?.status;
    return status != WorkNodeStatus.running && status != WorkNodeStatus.done;
  }

  Future<void> _assignProjectAgent(
    BuildContext context,
    WorkflowCapability capability,
  ) async {
    final flow = workflow;
    if (flow == null || !_canAssign(capability)) return;
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(
          AppLocalizations.of(context).panelAgentForNode(capability.title),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: Text(
              AppLocalizations.of(context).panelOverrideScope(project.name),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(''),
            child: Text('Usar default (${capability.role})'),
          ),
          for (final member in members)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(member.id),
              child: Text('@${member.name} · ${member.role}'),
            ),
        ],
      ),
    );
    if (picked == null) return;
    ProjectsService.instance.notifier.setWorkflowNodeAssignment(
      project.id,
      flow.id,
      capability.id,
      picked.isEmpty ? null : picked,
    );
  }

  Future<void> _assignSharedRole(
    BuildContext context,
    WorkflowCapability capability,
  ) async {
    final flow = workflow;
    if (flow == null || !_canAssign(capability)) return;
    final capabilities = _capabilitiesOf(AppLocalizations.of(context));
    final roles = {
      for (final member in members)
        if (member.role.trim().isNotEmpty) member.role.trim(),
    }.toList()..sort();
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppLocalizations.of(context).panelChangeSharedDefault),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: Text(
              AppLocalizations.of(context).panelSharedChangeScope(flow.name),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          for (final role in roles)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(role),
              child: Text(role),
            ),
        ],
      ),
    );
    if (picked == null) return;
    WorkflowsService.instance.notifier.updateWorkflow(
      flow.id,
      name: flow.name,
      whenToApply: flow.whenToApply,
      capabilities: [
        for (final entry in capabilities)
          entry.id == capability.id ? entry.copyWith(role: picked) : entry,
      ],
    );
  }

  Future<void> _tuneEngine(
    BuildContext context,
    WorkflowCapability capability,
  ) async {
    final owner = _ownerOf(capability);
    if (owner == null || !_canAssign(capability)) return;
    await openMemberEnginePanel(context, project: project, member: owner);
  }

  String? _consultedIn(AppLocalizations t, String nodeId) {
    final names = <String>{};
    for (final message in session?.messages ?? const []) {
      if (message.workNodeId != nodeId ||
          message.consultOfProfileId == null ||
          message.authorProfileId == null) {
        continue;
      }
      final member = members
          .where((entry) => entry.id == message.authorProfileId)
          .firstOrNull;
      if (member != null) names.add(member.name);
    }
    return names.isEmpty ? null : t.panelConsultedTo(names.join(', '));
  }

  List<ResolutionFinding> _findingsOf(String nodeId) =>
      session?.resolutionCase?.findings
          .where((finding) => finding.affectedNodeId == nodeId)
          .toList() ??
      const [];

  List<String> _gatesOf(String capabilityId) {
    final gates = workflow?.policy.qualityGates ?? const [];
    return [
      for (final gate in gates)
        if ((gate == WorkflowQualityGate.analysis &&
                (capabilityId == 'planner' || capabilityId == 'triage')) ||
            (gate != WorkflowQualityGate.analysis &&
                capabilityId == 'verification'))
          gate.name,
    ];
  }

  String? _coverageOf(AppLocalizations t, String capabilityId) {
    if (capabilityId != 'impact') return null;
    final coverage = session?.resolutionCase?.coverage ?? const [];
    if (coverage.isEmpty) return null;
    final resolved = coverage
        .where((entry) => entry.status != MigrationCoverageStatus.pending)
        .length;
    return t.panelCoverageMatrix(resolved, coverage.length);
  }

  Future<void> _activateCapability(
    BuildContext context,
    WorkflowCapability capability,
  ) async {
    final open = session;
    if (open == null) return;
    final error = await ProjectsService.instance.notifier
        .activateWorkflowCapability(project.id, open.id, capability.id);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _approveCapability(
    BuildContext context,
    WorkflowCapability capability,
  ) async {
    final open = session;
    if (open == null) return;
    final error = await ProjectsService.instance.notifier
        .approveWorkflowCapability(project.id, open.id, capability.id);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _addRule(BuildContext context) async {
    final rules = RulesService.instance.notifier.data.rules
        .where((rule) => !project.ruleNames.contains(rule.name))
        .toList();
    if (rules.isEmpty) return openRuleFormScreen(context);
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppLocalizations.of(context).panelAddRule),
        children: [
          for (final rule in rules)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(rule.name),
              child: Text(rule.name),
            ),
        ],
      ),
    );
    if (picked != null) {
      ProjectsService.instance.notifier.addRule(project.id, picked);
    }
  }

  Future<void> _addKnowledge(BuildContext context) async {
    final bases = KnowledgeService.instance.notifier.data.bases
        .where((base) => !project.knowledgeBaseNames.contains(base.name))
        .toList();
    if (bases.isEmpty) return openKnowledgeBaseFormScreen(context);
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppLocalizations.of(context).panelAddKnowledge),
        children: [
          for (final base in bases)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(base.name),
              child: Text(base.name),
            ),
        ],
      ),
    );
    if (picked != null) {
      ProjectsService.instance.notifier.addKnowledgeBase(project.id, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = workflow;
    final capabilities = _capabilitiesOf(AppLocalizations.of(context));
    final resolution = session?.resolutionCase;
    final done =
        resolution?.nodes
            .where((node) => node.status == WorkNodeStatus.done)
            .length ??
        0;
    final active =
        resolution?.nodes.length ??
        capabilities
            .where(
              (entry) =>
                  entry.activation == WorkflowCapabilityActivation.required,
            )
            .length;
    final engines = {
      for (final capability in capabilities)
        if (_ownerOf(capability) case final owner?)
          project.tuned(owner).provider,
    };
    final requiredSkills = {
      ...?flow?.skillNames,
      ...?flow?.policy.requiredSkillNames,
    };
    final rules = {...?flow?.policy.requiredRuleNames, ...project.ruleNames};
    final knowledge = {
      ...?flow?.policy.requiredKnowledgeBaseNames,
      ...project.knowledgeBaseNames,
    };
    final preflight = resolution?.preflight;
    final credentialProviders = {
      ...engines.where((entry) => entry.requiresApiKey),
      for (final secret in preflight?.missingSecrets ?? const <String>[])
        ...AgentProvider.values.where((entry) => entry.secretName == secret),
    };

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _GroupHead(label: AppLocalizations.of(context).panelTitleInProgress),
        if (flow == null)
          _PanelNote(AppLocalizations.of(context).panelNoWorkflowSelected)
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
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
                Text(
                  AppLocalizations.of(context).panelProgressOf(done, active),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 12, 8),
            child: Text(
              AppLocalizations.of(context).panelReviewCycles(
                resolution?.reviewCycleCount ?? 0,
                flow.policy.maxReviewCycles,
              ),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9.5,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          if (preflight != null && preflight.performed && !preflight.ready)
            _PanelNote('Preflight bloqueado: ${preflight.errorSummary}'),
          for (var index = 0; index < capabilities.length; index++)
            _CapabilityRow(
              capability: _displayCapability(
                AppLocalizations.of(context),
                capabilities[index],
              ),
              isLast: index == capabilities.length - 1,
              state: _stateOf(capabilities[index]),
              owner: _ownerOf(capabilities[index]),
              engine: _engineOf(capabilities[index]),
              isTuned: project.memberTuning.containsKey(
                _ownerOf(capabilities[index])?.id,
              ),
              ownerIndex: members.indexWhere(
                (member) => member.id == _ownerOf(capabilities[index])?.id,
              ),
              consulted: _consultedIn(
                AppLocalizations.of(context),
                capabilities[index].id,
              ),
              findings: _findingsOf(capabilities[index].id),
              gates: _gatesOf(capabilities[index].id),
              coverage: _coverageOf(
                AppLocalizations.of(context),
                capabilities[index].id,
              ),
              canEdit: _canAssign(capabilities[index]),
              onAssign: () => _assignProjectAgent(context, capabilities[index]),
              onSharedRole: () =>
                  _assignSharedRole(context, capabilities[index]),
              onTuneEngine: () => _tuneEngine(context, capabilities[index]),
              onActivate: () =>
                  _activateCapability(context, capabilities[index]),
              onApprove:
                  capabilities[index].executor ==
                          WorkflowExecutor.manualApproval &&
                      _nodeOf(capabilities[index].id)?.status ==
                          WorkNodeStatus.paused
                  ? () => _approveCapability(context, capabilities[index])
                  : null,
            ),
        ],
        if (requiredSkills.isNotEmpty) ...[
          _GroupHead(label: AppLocalizations.of(context).panelSectionSkills),
          for (final skill in requiredSkills)
            _BulletRow(
              label: skill,
              filled: false,
              required: true,
              missing: preflight?.missingSkills.contains(skill) ?? false,
            ),
        ],
        _GroupHead(
          label: AppLocalizations.of(context).panelSectionRules,
          onAdd: () => _addRule(context),
        ),
        for (final rule in rules)
          _BulletRow(
            label: rule,
            filled: true,
            required: flow?.policy.requiredRuleNames.contains(rule) ?? false,
            missing: preflight?.missingRules.contains(rule) ?? false,
            onRemove: project.ruleNames.contains(rule)
                ? () => ProjectsService.instance.notifier.removeRule(
                    project.id,
                    rule,
                  )
                : null,
          ),
        _GroupHead(
          label: AppLocalizations.of(context).panelSectionKnowledge,
          onAdd: () => _addKnowledge(context),
        ),
        for (final base in knowledge)
          _BulletRow(
            label: base,
            filled: false,
            required:
                flow?.policy.requiredKnowledgeBaseNames.contains(base) ?? false,
            missing: preflight?.missingKnowledge.contains(base) ?? false,
            onRemove: project.knowledgeBaseNames.contains(base)
                ? () => ProjectsService.instance.notifier.removeKnowledgeBase(
                    project.id,
                    base,
                  )
                : null,
          ),
        for (final provider in credentialProviders)
          ProviderCredentialCard(provider: provider, compact: true),
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
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, onAdd == null ? 16 : 6, 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                letterSpacing: 1.1,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          if (onAdd != null)
            IconButton(
              tooltip: AppLocalizations.of(context).panelAddToProject,
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 15),
              constraints: const BoxConstraints.tightFor(width: 26, height: 26),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow({
    required this.capability,
    required this.isLast,
    required this.state,
    required this.owner,
    required this.engine,
    required this.isTuned,
    required this.ownerIndex,
    required this.consulted,
    required this.findings,
    required this.gates,
    required this.coverage,
    required this.canEdit,
    required this.onAssign,
    required this.onSharedRole,
    required this.onTuneEngine,
    required this.onActivate,
    this.onApprove,
  });

  final WorkflowCapability capability;
  final bool isLast;
  final _CapabilityState state;
  final AgentProfile? owner;
  final AgentProfile? engine;
  final bool isTuned;
  final int ownerIndex;
  final String? consulted;
  final List<ResolutionFinding> findings;
  final List<String> gates;
  final String? coverage;
  final bool canEdit;
  final VoidCallback onAssign;
  final VoidCallback onSharedRole;
  final VoidCallback onTuneEngine;
  final VoidCallback onActivate;
  final VoidCallback? onApprove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = switch (state) {
      _CapabilityState.done => scheme.tertiary,
      _CapabilityState.current => scheme.primary,
      _CapabilityState.blocked => scheme.error,
      _CapabilityState.available => scheme.secondary,
      _CapabilityState.pending ||
      _CapabilityState.notRequired => scheme.outline,
    };
    final filled = state == _CapabilityState.done;
    final faded = state == _CapabilityState.notRequired;
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
                    color: filled ? accent : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accent,
                      width: state == _CapabilityState.current ? 2.5 : 1.5,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: filled ? accent : scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: Opacity(
                  opacity: faded ? 0.48 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              capability.title,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: state == _CapabilityState.current
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: state == _CapabilityState.available
                                ? onActivate
                                : null,
                            child: Tooltip(
                              message: state == _CapabilityState.available
                                  ? AppLocalizations.of(context).panelActivateOptional
                                  : _stateLabel(AppLocalizations.of(context), state),
                              child: Text(
                                _stateLabel(AppLocalizations.of(context), state),
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 9.5,
                                  color: accent,
                                  decoration:
                                      state == _CapabilityState.available
                                      ? TextDecoration.underline
                                      : null,
                                ),
                              ),
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
                              onTap: canEdit ? onAssign : null,
                              child: Text(
                                owner?.name ??
                                    AppLocalizations.of(
                                      context,
                                    ).panelNoAgentForRole(capability.role),
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
                          if (canEdit)
                            InkWell(
                              onTap: onSharedRole,
                              child: Tooltip(
                                message: AppLocalizations.of(context).panelChangeDefaultRole,
                                child: Icon(
                                  Icons.more_horiz,
                                  size: 15,
                                  color: scheme.outline,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (engine != null)
                        _EngineLine(
                          engine: engine!,
                          isTuned: isTuned,
                          onTap: canEdit ? onTuneEngine : null,
                        ),
                      Text(
                        _executorLabel(
                          AppLocalizations.of(context),
                          capability.executor,
                        ),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9.5,
                          color: scheme.outline,
                        ),
                      ),
                      if (onApprove != null)
                        TextButton.icon(
                          onPressed: onApprove,
                          icon: const Icon(Icons.verified_outlined, size: 15),
                          label: Text(AppLocalizations.of(context).panelApproveAndContinue),
                        ),
                      if (consulted != null)
                        Text(
                          consulted!,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontStyle: FontStyle.italic,
                            color: scheme.outline,
                          ),
                        ),
                      if (gates.isNotEmpty)
                        Text(
                          'gates · ${gates.join(', ')}',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: scheme.outline,
                          ),
                        ),
                      if (coverage != null)
                        Text(
                          coverage!,
                          style: TextStyle(
                            fontSize: 9.5,
                            color: scheme.outline,
                          ),
                        ),
                      for (final finding in findings)
                        Text(
                          '⚠ ${finding.evidence.summary}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: scheme.error),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _stateLabel(AppLocalizations t, _CapabilityState state) =>
    switch (state) {
      _CapabilityState.done => t.panelStateDone,
      _CapabilityState.current => t.panelStateCurrent,
      _CapabilityState.pending => t.panelStatePending,
      _CapabilityState.blocked => t.panelStateBlocked,
      _CapabilityState.available => t.panelStateAvailable,
      _CapabilityState.notRequired => t.panelStateNotRequired,
    };

String _executorLabel(AppLocalizations t, WorkflowExecutor executor) =>
    switch (executor) {
      WorkflowExecutor.newSession => t.panelExecutorNewSession,
      WorkflowExecutor.resumeParent => t.panelExecutorResumeParent,
      WorkflowExecutor.providerSubagent => t.panelExecutorSubagent,
      WorkflowExecutor.manualApproval => t.panelExecutorManualApproval,
    };

class _EngineLine extends StatelessWidget {
  const _EngineLine({
    required this.engine,
    required this.isTuned,
    required this.onTap,
  });

  final AgentProfile engine;
  final bool isTuned;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effort = engine.provider == AgentProvider.codex
        ? ''
        : ' · ${effortLabel(engine.effort)}';
    return Padding(
      padding: const EdgeInsets.only(top: 3, left: 21),
      child: InkWell(
        onTap: onTap,
        child: Text(
          '${modelLabelFor(engine.provider, engine.model)}$effort · '
          '${engine.provider.label}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: isTuned ? scheme.primary : scheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({
    required this.label,
    required this.filled,
    required this.required,
    this.missing = false,
    this.onRemove,
  });

  final String label;
  final bool filled;
  final bool required;
  final bool missing;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 3, 6, 3),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: filled && !missing ? scheme.primary : Colors.transparent,
              border: Border.all(
                color: missing ? scheme.error : scheme.primary,
                width: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: missing ? scheme.error : null,
              ),
            ),
          ),
          if (required)
            Tooltip(
              message: AppLocalizations.of(context).panelRequiredByWorkflow,
              child: Icon(Icons.lock_outline, size: 12, color: scheme.outline),
            ),
          if (missing)
            Tooltip(
              message: AppLocalizations.of(context).panelMissingBlocksPreflight,
              child: Icon(Icons.error_outline, size: 13, color: scheme.error),
            ),
          if (onRemove != null)
            IconButton(
              tooltip: AppLocalizations.of(context).panelRemoveFromProject,
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 13),
              constraints: const BoxConstraints.tightFor(width: 26, height: 26),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}

class _PanelNote extends StatelessWidget {
  const _PanelNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}
