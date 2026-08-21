import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/model/claude_model_option.dart';
import 'package:keel_ui/src/modules/agents/model/effort_level.dart';
import 'package:keel_ui/src/modules/assistant/model/assistant_action.dart';
import 'package:keel_ui/src/modules/rules/viewmodel/rules_viewmodel.dart';
import 'package:keel_ui/src/modules/skills/viewmodel/skills_viewmodel.dart';
import 'package:keel_ui/src/modules/stations/viewmodel/stations_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';

/// Runs every parsed action against the same ViewModels the app's own forms
/// use — nothing here talks to a repository directly. [actions] must already
/// be in dependency order (skills/rules, then agents, then workflows, then
/// stations) — see `assistant_action_parser.dart`.
List<AssistantActionResult> executeAssistantActions(
  List<AssistantAction> actions,
) {
  return [
    for (final action in actions)
      switch (action) {
        CreateSkillAction() => _executeSkill(action),
        CreateRuleAction() => _executeRule(action),
        CreateAgentAction() => _executeAgent(action),
        CreateWorkflowAction() => _executeWorkflow(action),
        CreateStationAction() => _executeStation(action),
      },
  ];
}

AssistantActionResult _executeSkill(CreateSkillAction action) {
  final viewmodel = SkillsService.instance.notifier;
  if (viewmodel.data.skills.any((skill) => skill.name == action.name)) {
    return AssistantActionResult(
      action: action,
      ok: true,
      message: 'La skill "${action.name}" ya existía, la reusé.',
    );
  }
  final error = viewmodel.createSkill(
    name: action.name,
    content: action.content,
  );
  return AssistantActionResult(
    action: action,
    ok: error == null,
    message: error ?? 'Creé la skill "${action.name}".',
  );
}

AssistantActionResult _executeRule(CreateRuleAction action) {
  final viewmodel = RulesService.instance.notifier;
  if (viewmodel.data.rules.any((rule) => rule.name == action.name)) {
    return AssistantActionResult(
      action: action,
      ok: true,
      message: 'La regla "${action.name}" ya existía, la reusé.',
    );
  }
  final error = viewmodel.createRule(
    name: action.name,
    content: action.content,
  );
  return AssistantActionResult(
    action: action,
    ok: error == null,
    message: error ?? 'Creé la regla "${action.name}".',
  );
}

AssistantActionResult _executeAgent(CreateAgentAction action) {
  if (action.handle == kKeelAiHandle) {
    return AssistantActionResult(
      action: action,
      ok: false,
      message: 'El handle "${action.handle}" está reservado.',
    );
  }

  final viewmodel = AgentProfilesService.instance.notifier;
  final existing = viewmodel.data.profiles
      .where((profile) => profile.name == action.handle)
      .firstOrNull;

  if (existing == null) {
    final systemPrompt = [
      action.purpose,
      action.instructions,
    ].whereType<String>().where((part) => part.isNotEmpty).join('\n\n');
    final error = viewmodel.createProfile(
      name: action.handle,
      role: action.role ?? action.handle,
      systemPrompt: systemPrompt,
      skills: action.skillNames,
      rules: action.ruleNames,
      model: kDefaultClaudeModelAlias,
      effort: kDefaultEffortAlias,
      // Not attributed to keelai: this agent isn't spawned inside a station
      // task, so a "spawn" edge in a station's map view would be spurious.
      createdByProfileId: null,
    );
    return AssistantActionResult(
      action: action,
      ok: error == null,
      message: error ?? 'Registré a @${action.handle}.',
    );
  }

  // Update is additive only: skills/rules are a union with what the profile
  // already had, and a field the block didn't mention is left untouched.
  final mergedSkills = {...existing.skills, ...action.skillNames}.toList();
  final mergedRules = {...existing.rules, ...action.ruleNames}.toList();
  final instructions = action.instructions;
  final systemPrompt = instructions == null
      ? existing.systemPrompt
      : [
          existing.systemPrompt,
          instructions,
        ].where((part) => part.isNotEmpty).join('\n\n');

  final error = viewmodel.updateProfile(
    existing.id,
    name: existing.name,
    role: action.role ?? existing.role,
    systemPrompt: systemPrompt,
    skills: mergedSkills,
    rules: mergedRules,
    model: existing.model,
    effort: existing.effort,
  );
  return AssistantActionResult(
    action: action,
    ok: error == null,
    message: error ?? 'Actualicé a @${action.handle}.',
  );
}

AssistantActionResult _executeWorkflow(CreateWorkflowAction action) {
  final viewmodel = WorkflowsService.instance.notifier;
  if (viewmodel.data.workflows.any(
    (workflow) => workflow.name == action.name,
  )) {
    return AssistantActionResult(
      action: action,
      ok: true,
      message: 'El workflow "${action.name}" ya existía, lo reusé.',
    );
  }
  if (action.steps.isEmpty) {
    return AssistantActionResult(
      action: action,
      ok: false,
      message: 'El workflow "${action.name}" no tiene pasos válidos.',
    );
  }
  final error = viewmodel.createWorkflow(
    name: action.name,
    whenToApply: action.whenToApply,
    steps: action.steps,
  );
  return AssistantActionResult(
    action: action,
    ok: error == null,
    message:
        error ??
        'Creé el workflow "${action.name}" (${action.steps.length} pasos).',
  );
}

AssistantActionResult _executeStation(CreateStationAction action) {
  final profiles = AgentProfilesService.instance.notifier.data.profiles;
  final workflows = WorkflowsService.instance.notifier.data.workflows;

  final profileIds = <String>[];
  final unresolvedAgents = <String>[];
  for (final handle in action.agentHandles) {
    final id = profiles.where((p) => p.name == handle).firstOrNull?.id;
    if (id == null) {
      unresolvedAgents.add(handle);
    } else {
      profileIds.add(id);
    }
  }

  final workflowIds = <String>[];
  final unresolvedWorkflows = <String>[];
  for (final name in action.workflowNames) {
    final id = workflows.where((w) => w.name == name).firstOrNull?.id;
    if (id == null) {
      unresolvedWorkflows.add(name);
    } else {
      workflowIds.add(id);
    }
  }

  final error = StationsService.instance.notifier.createStation(
    name: action.name,
    purpose: action.purpose,
    workingDirectory: action.workingDirectory,
    profileIds: profileIds,
    workflowIds: workflowIds,
    ruleNames: action.ruleNames,
    documentPaths: const [],
  );
  if (error != null) {
    return AssistantActionResult(action: action, ok: false, message: error);
  }

  final warnings = [
    if (unresolvedAgents.isNotEmpty)
      'no encontré a ${unresolvedAgents.join(', ')}',
    if (unresolvedWorkflows.isNotEmpty)
      'no encontré el workflow ${unresolvedWorkflows.join(', ')}',
  ];
  final message = warnings.isEmpty
      ? 'Creé la estación "${action.name}".'
      : 'Creé la estación "${action.name}" (${warnings.join('; ')}).';
  return AssistantActionResult(action: action, ok: true, message: message);
}

/// One line per action, in order — the trace message appended to the chat
/// after a Keel AI turn. Empty when [results] has nothing to report.
String summarizeAssistantActionResults(List<AssistantActionResult> results) {
  if (results.isEmpty) return '';
  return results.map((result) => '- ${result.message}').join('\n');
}
