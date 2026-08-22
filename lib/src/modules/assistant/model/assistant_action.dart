import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

/// One action Keel AI asked for by writing a fenced block in its reply.
/// Plain data — parsed from text by `assistant_action_parser.dart`, executed
/// by `assistant_action_executor.dart`.
sealed class AssistantAction {
  const AssistantAction();
}

class CreateProjectAction extends AssistantAction {
  final String name;
  final String purpose;
  final String workingDirectory;
  final List<String> agentHandles;
  final List<String> workflowNames;
  final List<String> ruleNames;
  final List<String> knowledgeBaseNames;

  const CreateProjectAction({
    required this.name,
    required this.purpose,
    required this.workingDirectory,
    required this.agentHandles,
    required this.workflowNames,
    required this.ruleNames,
    this.knowledgeBaseNames = const [],
  });
}

/// Creates the profile if [handle] is new, or additively updates it if it
/// already exists — [skillNames]/[ruleNames] are merged into whatever the
/// profile already had, never replacing it. [role]/[purpose]/[instructions]
/// stay nullable rather than defaulting in the parser, so the executor can
/// tell "the block didn't mention this" from "the block set it to this" —
/// which matters only on update, where an unset field must leave the
/// existing profile alone instead of overwriting it with a guessed default.
class CreateAgentAction extends AssistantAction {
  final String handle;
  final String? role;
  final String? purpose;
  final String? instructions;
  final List<String> skillNames;
  final List<String> ruleNames;
  final List<String> toolNames;
  final List<String> mcpServerNames;
  final List<String> knowledgeBaseNames;

  /// Provider alias ('claude'/'codex'); null on update = keep existing.
  final String? providerAlias;

  /// Grants the profile the `keelai-actions` MCP (a "builder" agent that
  /// can create things in the system). Nullable so an update that doesn't
  /// mention it leaves the existing grant untouched.
  final bool? systemBuilder;

  const CreateAgentAction({
    required this.handle,
    required this.role,
    required this.purpose,
    required this.instructions,
    required this.skillNames,
    required this.ruleNames,
    this.toolNames = const [],
    this.knowledgeBaseNames = const [],
    this.mcpServerNames = const [],
    this.providerAlias,
    this.systemBuilder,
  });
}

class CreateWorkflowAction extends AssistantAction {
  final String name;
  final String whenToApply;
  final List<WorkflowStep> steps;

  const CreateWorkflowAction({
    required this.name,
    required this.whenToApply,
    required this.steps,
  });
}

class CreateSkillAction extends AssistantAction {
  final String name;
  final String content;
  final bool isGlobal;

  const CreateSkillAction({
    required this.name,
    required this.content,
    this.isGlobal = false,
  });
}

class CreateRuleAction extends AssistantAction {
  final String name;
  final String content;

  const CreateRuleAction({required this.name, required this.content});
}

/// Registers an executable tool. Only reachable through the real MCP tool
/// (`create_tool`) — there is deliberately NO fenced-block form for this
/// one: the block parser collapses blank lines and trims indentation, which
/// destroys script code (Python dies on it), while MCP arguments arrive
/// byte-exact.
class CreateToolAction extends AssistantAction {
  final String name;
  final String description;
  final String runtimeAlias;
  final String code;
  final int? timeoutSeconds;
  final List<String> secretNames;

  const CreateToolAction({
    required this.name,
    required this.description,
    required this.runtimeAlias,
    required this.code,
    required this.timeoutSeconds,
    this.secretNames = const [],
  });
}

/// What happened when one [action] ran. One-shot, not persisted — folded
/// into a trace message right after execution, not kept around.
class AssistantActionResult {
  final AssistantAction action;
  final bool ok;
  final String message;

  const AssistantActionResult({
    required this.action,
    required this.ok,
    required this.message,
  });
}
