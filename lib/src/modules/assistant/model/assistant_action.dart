import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

/// One action Keel AI asked for by writing a fenced block in its reply.
/// Plain data — parsed from text by `assistant_action_parser.dart`, executed
/// by `assistant_action_executor.dart`.
sealed class AssistantAction {
  const AssistantAction();
}

class CreateStationAction extends AssistantAction {
  final String name;
  final String purpose;
  final String workingDirectory;
  final List<String> agentHandles;
  final List<String> workflowNames;
  final List<String> ruleNames;

  const CreateStationAction({
    required this.name,
    required this.purpose,
    required this.workingDirectory,
    required this.agentHandles,
    required this.workflowNames,
    required this.ruleNames,
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

  const CreateAgentAction({
    required this.handle,
    required this.role,
    required this.purpose,
    required this.instructions,
    required this.skillNames,
    required this.ruleNames,
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

  const CreateSkillAction({required this.name, required this.content});
}

class CreateRuleAction extends AssistantAction {
  final String name;
  final String content;

  const CreateRuleAction({required this.name, required this.content});
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
