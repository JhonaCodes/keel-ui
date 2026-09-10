import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart';
import 'package:keel_ui/src/modules/agents/model/effort_level.dart';
import 'package:keel_ui/src/modules/assistant/model/assistant_action.dart';
import 'package:keel_ui/src/modules/knowledge/viewmodel/knowledge_viewmodel.dart';
import 'package:keel_ui/src/modules/hooks/viewmodel/hooks_viewmodel.dart';
import 'package:keel_ui/src/modules/mcp_servers/viewmodel/mcp_servers_viewmodel.dart';
import 'package:keel_ui/src/modules/rules/viewmodel/rules_viewmodel.dart';
import 'package:keel_ui/src/modules/skills/viewmodel/skills_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/tools/model/tool.dart';
import 'package:keel_ui/src/modules/tools/viewmodel/tools_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

/// Runs every parsed action against the same ViewModels the app's own forms
/// use — nothing here talks to a repository directly. [actions] must already
/// be in dependency order (skills/rules, then agents, then workflows, then
/// projects) — see `assistant_action_parser.dart`.
List<AssistantActionResult> executeAssistantActions(
  List<AssistantAction> actions, {
  AppLocalizations? l10n,
}) {
  return [
    for (final action in actions)
      switch (action) {
        CreateSkillAction() => executeSkillAction(action, l10n: l10n),
        CreateRuleAction() => executeRuleAction(action, l10n: l10n),
        CreateToolAction() => executeToolAction(action, l10n: l10n),
        CreateAgentAction() => executeAgentAction(action, l10n: l10n),
        CreateWorkflowAction() => executeWorkflowAction(action, l10n: l10n),
        CreateProjectAction() => executeProjectAction(action, l10n: l10n),
      },
  ];
}

AssistantActionResult executeSkillAction(
  CreateSkillAction action, {
  AppLocalizations? l10n,
}) {
  final viewmodel = SkillsService.instance.notifier;
  if (viewmodel.data.skills.any((skill) => skill.name == action.name)) {
    return AssistantActionResult(
      action: action,
      ok: true,
      message:
          l10n?.assistantSkillExists(action.name) ??
          'The skill "${action.name}" already existed; I reused it.',
    );
  }
  final error = viewmodel.createSkill(
    name: action.name,
    content: action.content,
    isGlobal: action.isGlobal,
  );
  return AssistantActionResult(
    action: action,
    ok: error == null,
    message:
        error ??
        l10n?.assistantSkillCreated(
          action.name,
          action.isGlobal ? ' (global)' : '',
        ) ??
        'I created the skill "${action.name}"${action.isGlobal ? ' (global)' : ''}.',
  );
}

AssistantActionResult executeRuleAction(
  CreateRuleAction action, {
  AppLocalizations? l10n,
}) {
  final viewmodel = RulesService.instance.notifier;
  if (viewmodel.data.rules.any((rule) => rule.name == action.name)) {
    return AssistantActionResult(
      action: action,
      ok: true,
      message:
          l10n?.assistantRuleExists(action.name) ??
          'The rule "${action.name}" already existed; I reused it.',
    );
  }
  final error = viewmodel.createRule(
    name: action.name,
    content: action.content,
  );
  return AssistantActionResult(
    action: action,
    ok: error == null,
    message:
        error ??
        l10n?.assistantRuleCreated(action.name) ??
        'I created the rule "${action.name}".',
  );
}

AssistantActionResult executeToolAction(
  CreateToolAction action, {
  AppLocalizations? l10n,
}) {
  final viewmodel = ToolsService.instance.notifier;
  if (viewmodel.data.tools.any((tool) => tool.name == action.name)) {
    return AssistantActionResult(
      action: action,
      ok: true,
      message:
          l10n?.assistantToolExists(action.name) ??
          'The tool "${action.name}" already existed; I reused it.',
    );
  }

  final runtime = ToolRuntime.tryFromAlias(action.runtimeAlias);
  if (runtime == null) {
    return AssistantActionResult(
      action: action,
      ok: false,
      message:
          'Runtime "${action.runtimeAlias}" desconocido para la tool '
          '"${action.name}" — válidos: bash, python, dart.',
    );
  }

  final error = viewmodel.createTool(
    name: action.name,
    description: action.description,
    runtime: runtime,
    code: action.code,
    timeoutSeconds: action.timeoutSeconds ?? kDefaultToolTimeoutSeconds,
    secretNames: action.secretNames,
  );
  return AssistantActionResult(
    action: action,
    ok: error == null,
    message:
        error ??
        l10n?.assistantToolCreated(action.name, runtime.label) ??
        'I created the tool "${action.name}" (${runtime.label}).',
  );
}

AssistantActionResult executeAgentAction(
  CreateAgentAction action, {
  AppLocalizations? l10n,
}) {
  final providerAlias = action.providerAlias;
  final provider = providerAlias == null
      ? null
      : AgentProvider.tryFromAlias(providerAlias);
  if (providerAlias != null && provider == null) {
    return AssistantActionResult(
      action: action,
      ok: false,
      message:
          'Proveedor "$providerAlias" desconocido — válidos: '
          '${AgentProvider.values.map((entry) => entry.alias).join(', ')}.',
    );
  }

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

  // Un nombre que no existe en el catálogo queda como asignación colgada:
  // el agente cree que tiene esa skill y en el turno no le llega nada. Se
  // asignan las válidas y las descartadas se nombran en la respuesta, para
  // que el modelo se entere de que inventó un nombre.
  final skills = _keepKnown(
    action.skillNames,
    known: SkillsService.instance.notifier.data.skills.map(
      (skill) => skill.name,
    ),
  );
  final rules = _keepKnown(
    action.ruleNames,
    known: RulesService.instance.notifier.data.rules.map((rule) => rule.name),
  );
  final tools = _keepKnown(
    action.toolNames,
    known: ToolsService.instance.notifier.data.tools.map((tool) => tool.name),
  );
  final mcpServers = _keepKnown(
    action.mcpServerNames,
    known: McpServersService.instance.notifier.data.servers.map(
      (server) => server.name,
    ),
  );
  final knowledgeBases = _keepKnown(
    action.knowledgeBaseNames,
    known: KnowledgeService.instance.notifier.data.bases.map(
      (base) => base.name,
    ),
  );
  final hooks = _keepKnown(
    action.hookNames,
    known: HooksService.instance.notifier.data.hooks.map((hook) => hook.name),
  );
  final dropped = _describeDropped({
    'skills': skills.dropped,
    'reglas': rules.dropped,
    'tools': tools.dropped,
    'MCPs': mcpServers.dropped,
    'bases de saber': knowledgeBases.dropped,
    'hooks': hooks.dropped,
  });

  if (existing == null) {
    final systemPrompt = [
      action.purpose,
      action.instructions,
    ].whereType<String>().where((part) => part.isNotEmpty).join('\n\n');
    final error = viewmodel.createProfile(
      name: action.handle,
      role: action.role ?? action.handle,
      systemPrompt: systemPrompt,
      skills: skills.kept,
      rules: rules.kept,
      hooks: hooks.kept,
      tools: tools.kept,
      mcpServers: mcpServers.kept,
      knowledgeBaseNames: knowledgeBases.kept,
      canManageSystem: action.systemBuilder ?? false,
      provider: provider ?? AgentProvider.claude,
      // Per provider: a codex agent seeded with a Claude alias would carry a
      // model its own CLI has never heard of.
      model: action.model?.trim().isNotEmpty == true
          ? action.model!.trim()
          : defaultModelFor(provider ?? AgentProvider.claude),
      effort: action.effort?.trim().isNotEmpty == true
          ? action.effort!.trim()
          : kDefaultEffortAlias,
      // Not attributed to keelai: this agent isn't spawned inside a project
      // session, so a "spawn" edge in a project's map view would be spurious.
      createdByProfileId: null,
    );
    return AssistantActionResult(
      action: action,
      ok: error == null,
      message:
          error ??
          l10n?.assistantAgentCreated(action.handle, dropped) ??
          'I registered @${action.handle}.$dropped',
    );
  }

  // Update is additive only: skills/rules/tools are a union with what the
  // profile already had, and a field the block didn't mention is left
  // untouched.
  final mergedSkills = {...existing.skills, ...skills.kept}.toList();
  final mergedRules = {...existing.rules, ...rules.kept}.toList();
  final mergedTools = {...existing.tools, ...tools.kept}.toList();
  final mergedMcpServers = {
    ...existing.mcpServers,
    ...mcpServers.kept,
  }.toList();
  final mergedKnowledgeBases = {
    ...existing.knowledgeBaseNames,
    ...knowledgeBases.kept,
  }.toList();
  final mergedHooks = {...existing.hooks, ...hooks.kept}.toList();
  final instructions = action.instructions;
  final systemPrompt = instructions == null
      ? existing.systemPrompt
      : [
          existing.systemPrompt,
          instructions,
        ].where((part) => part.isNotEmpty).join('\n\n');

  final resolvedProvider = provider ?? existing.provider;
  final requestedModel = action.model?.trim();
  final resolvedModel = requestedModel?.isNotEmpty == true
      ? requestedModel!
      : provider != null && provider != existing.provider
      ? defaultModelFor(resolvedProvider)
      : existing.model;
  final requestedEffort = action.effort?.trim();
  final error = viewmodel.updateProfile(
    existing.id,
    name: existing.name,
    role: action.role ?? existing.role,
    systemPrompt: systemPrompt,
    skills: mergedSkills,
    rules: mergedRules,
    hooks: mergedHooks,
    tools: mergedTools,
    mcpServers: mergedMcpServers,
    knowledgeBaseNames: mergedKnowledgeBases,
    canManageSystem: action.systemBuilder,
    provider: resolvedProvider,
    model: resolvedModel,
    effort: requestedEffort?.isNotEmpty == true
        ? requestedEffort!
        : existing.effort,
  );
  return AssistantActionResult(
    action: action,
    ok: error == null,
    message:
        error ??
        l10n?.assistantAgentUpdated(action.handle, dropped) ??
        'I updated @${action.handle}.$dropped',
  );
}

/// Los nombres que existen en el catálogo y los que no.
typedef _KnownNames = ({List<String> kept, List<String> dropped});

_KnownNames _keepKnown(
  List<String> requested, {
  required Iterable<String> known,
}) {
  final catalog = known.toSet();
  return (
    kept: requested.where(catalog.contains).toList(),
    dropped: requested.where((name) => !catalog.contains(name)).toList(),
  );
}

/// Una línea por tipo con lo que se descartó, o cadena vacía si todo
/// existía. Va pegada al mensaje de éxito: la acción se hizo, pero el
/// modelo tiene que ver qué pidió mal.
String _describeDropped(Map<String, List<String>> byKind) {
  final lines = [
    for (final entry in byKind.entries)
      if (entry.value.isNotEmpty)
        '⚠️ ${entry.key} ignoradas (no existen): ${entry.value.join(', ')}',
  ];
  if (lines.isEmpty) return '';
  return '\n${lines.join('\n')}';
}

AssistantActionResult executeWorkflowAction(
  CreateWorkflowAction action, {
  AppLocalizations? l10n,
}) {
  final viewmodel = WorkflowsService.instance.notifier;
  final existing = viewmodel.data.workflows
      .where((workflow) => workflow.name == action.name)
      .firstOrNull;
  final policy = WorkflowPolicy(
    resolutionRole: action.resolutionRole,
    requiredSkillNames: action.skillNames,
    requiredRuleNames: action.requiredRuleNames,
    requiredKnowledgeBaseNames: action.requiredKnowledgeBaseNames,
    qualityGates: action.qualityGates.isEmpty
        ? _defaultWorkflowGates(action.kind)
        : action.qualityGates,
    maxReplans: action.maxReplans ?? kDefaultMaxReplans,
    maxSubagents: action.maxSubagents ?? kDefaultMaxSubagents,
    maxReviewCycles: action.maxReviewCycles ?? kDefaultMaxReviewCycles,
  );
  final error = existing == null
      ? viewmodel.createWorkflow(
          name: action.name,
          whenToApply: action.whenToApply,
          kind: action.kind,
          policy: policy,
          skillNames: action.skillNames,
          buildsRoadmap: action.buildsRoadmap ?? false,
          capabilities: action.capabilities.isEmpty
              ? null
              : action.capabilities,
        )
      : viewmodel.updateWorkflow(
          existing.id,
          name: action.name,
          whenToApply: action.whenToApply.isEmpty
              ? existing.whenToApply
              : action.whenToApply,
          kind: action.kind,
          policy: policy,
          skillNames: action.skillNames,
          buildsRoadmap: action.buildsRoadmap,
          capabilities: action.capabilities.isEmpty
              ? null
              : action.capabilities,
        );
  if (error != null) {
    return AssistantActionResult(action: action, ok: false, message: error);
  }

  final profiles = AgentProfilesService.instance.notifier.data.profiles;
  final hasOwner =
      action.resolutionRole.trim().isEmpty ||
      memberForRole(profiles, action.resolutionRole) != null;

  return AssistantActionResult(
    action: action,
    ok: true,
    message: hasOwner
        ? '${existing == null ? 'Creé' : 'Actualicé'} el workflow '
              '"${action.name}" (${action.kind.name}).'
        : '${existing == null ? 'Creé' : 'Actualicé'} el workflow '
              '"${action.name}", pero el responsable '
              '"${action.resolutionRole}" todavía no existe. El preflight '
              'lo bloqueará hasta que se asigne.',
  );
}

List<WorkflowQualityGate> _defaultWorkflowGates(WorkflowKind kind) =>
    kind == WorkflowKind.migration
    ? WorkflowQualityGate.values
    : const [
        WorkflowQualityGate.analysis,
        WorkflowQualityGate.focusedTests,
        WorkflowQualityGate.regression,
      ];

AssistantActionResult executeProjectAction(
  CreateProjectAction action, {
  AppLocalizations? l10n,
}) {
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

  // Los agentes y workflows ya se resuelven arriba por id; las reglas van
  // por nombre y hasta acá pasaban sin verificar, así que una regla
  // inventada quedaba declarada en el proyecto sin existir.
  final rules = _keepKnown(
    action.ruleNames,
    known: RulesService.instance.notifier.data.rules.map((rule) => rule.name),
  );

  final bases = _keepKnown(
    action.knowledgeBaseNames,
    known: KnowledgeService.instance.notifier.data.bases.map(
      (base) => base.name,
    ),
  );
  final hooks = _keepKnown(
    action.hookNames,
    known: HooksService.instance.notifier.data.hooks.map((hook) => hook.name),
  );

  final error = ProjectsService.instance.notifier.createProject(
    name: action.name,
    purpose: action.purpose,
    workingDirectory: action.workingDirectory,
    profileIds: profileIds,
    workflowIds: workflowIds,
    ruleNames: rules.kept,
    hookNames: hooks.kept,
    knowledgeBaseNames: bases.kept,
    maintained: action.maintained,
  );
  if (error != null) {
    return AssistantActionResult(action: action, ok: false, message: error);
  }

  final warnings = [
    if (unresolvedAgents.isNotEmpty)
      'no encontré a ${unresolvedAgents.join(', ')}',
    if (unresolvedWorkflows.isNotEmpty)
      'no encontré el workflow ${unresolvedWorkflows.join(', ')}',
    if (rules.dropped.isNotEmpty)
      'no encontré la regla ${rules.dropped.join(', ')}',
    if (bases.dropped.isNotEmpty)
      'no encontré la base de saber ${bases.dropped.join(', ')}',
    if (hooks.dropped.isNotEmpty)
      'no encontré el hook ${hooks.dropped.join(', ')}',
  ];
  final message = warnings.isEmpty
      ? l10n?.assistantProjectCreated(action.name) ??
            'I created the project "${action.name}".'
      : 'Creé el proyecto "${action.name}" (${warnings.join('; ')}).';
  return AssistantActionResult(action: action, ok: true, message: message);
}

/// One line per action, in order — the trace message appended to the chat
/// after a Keel AI turn. Empty when [results] has nothing to report.
String summarizeAssistantActionResults(List<AssistantActionResult> results) {
  if (results.isEmpty) return '';
  return results.map((result) => '- ${result.message}').join('\n');
}
