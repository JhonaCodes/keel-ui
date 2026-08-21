part of '../assistant_mcp_server.dart';

/// Runs one tool call for [agentId]'s conversation and appends a live trace
/// line to that thread BEFORE returning the result to the model — the
/// point of using a real tool instead of a text block: this line appears
/// the moment the call happens, not as a summary once the whole turn ends.
Future<CallToolResult> dispatchKeelAiTool(
  String agentId,
  CallToolRequest request,
) async {
  final (ok, message) = _runKeelAiTool(request);
  AgentsService.instance.notifier.appendSystemNote(agentId, message);
  return CallToolResult(
    content: [TextContent(text: jsonEncode({'ok': ok, 'message': message}))],
    isError: !ok,
  );
}

(bool, String) _runKeelAiTool(CallToolRequest request) {
  final arguments = request.arguments ?? const <String, Object?>{};
  switch (request.name) {
    case 'create_skill':
      final result = executeSkillAction(
        CreateSkillAction(
          name: arguments['name'] as String,
          content: arguments['content'] as String,
        ),
      );
      return (result.ok, result.message);

    case 'create_rule':
      final result = executeRuleAction(
        CreateRuleAction(
          name: arguments['name'] as String,
          content: arguments['content'] as String,
        ),
      );
      return (result.ok, result.message);

    case 'create_or_update_agent':
      final result = executeAgentAction(
        CreateAgentAction(
          handle: arguments['handle'] as String,
          role: arguments['role'] as String?,
          purpose: arguments['purpose'] as String?,
          instructions: arguments['instructions'] as String?,
          skillNames: _stringList(arguments['skill_names']),
          ruleNames: _stringList(arguments['rule_names']),
        ),
      );
      return (result.ok, result.message);

    case 'create_workflow':
      final result = executeWorkflowAction(
        CreateWorkflowAction(
          name: arguments['name'] as String,
          whenToApply: arguments['when_to_apply'] as String? ?? '',
          steps: _parseToolSteps(arguments['steps']),
        ),
      );
      return (result.ok, result.message);

    case 'create_station':
      final result = executeStationAction(
        CreateStationAction(
          name: arguments['name'] as String,
          purpose: arguments['purpose'] as String? ?? '',
          workingDirectory: arguments['working_directory'] as String? ?? '',
          agentHandles: _stringList(arguments['agent_handles']),
          workflowNames: _stringList(arguments['workflow_names']),
          ruleNames: _stringList(arguments['rule_names']),
        ),
      );
      return (result.ok, result.message);

    case 'delete_skill':
      return _deleteByName(
        name: arguments['name'] as String,
        items: SkillsService.instance.notifier.data.skills,
        idOf: (skill) => skill.id,
        nameOf: (skill) => skill.name,
        delete: SkillsService.instance.notifier.deleteSkill,
        label: 'skill',
      );

    case 'delete_rule':
      return _deleteByName(
        name: arguments['name'] as String,
        items: RulesService.instance.notifier.data.rules,
        idOf: (rule) => rule.id,
        nameOf: (rule) => rule.name,
        delete: RulesService.instance.notifier.deleteRule,
        label: 'regla',
      );

    case 'delete_workflow':
      return _deleteByName(
        name: arguments['name'] as String,
        items: WorkflowsService.instance.notifier.data.workflows,
        idOf: (workflow) => workflow.id,
        nameOf: (workflow) => workflow.name,
        delete: WorkflowsService.instance.notifier.deleteWorkflow,
        label: 'workflow',
      );

    case 'delete_station':
      return _deleteByName(
        name: arguments['name'] as String,
        items: StationsService.instance.notifier.data.stations,
        idOf: (station) => station.id,
        nameOf: (station) => station.name,
        delete: StationsService.instance.notifier.deleteStation,
        label: 'estación',
      );

    case 'delete_agent':
      final handle = arguments['handle'] as String;
      if (handle == kKeelAiHandle) {
        return (false, 'No puedo eliminarme a mí mismo (@keelai).');
      }
      return _deleteByName(
        name: handle,
        items: AgentProfilesService.instance.notifier.data.profiles,
        idOf: (profile) => profile.id,
        nameOf: (profile) => profile.name,
        delete: AgentProfilesService.instance.notifier.deleteProfile,
        label: 'agente',
      );

    default:
      return (false, 'Tool desconocida: ${request.name}.');
  }
}

(bool, String) _deleteByName<T>({
  required String name,
  required List<T> items,
  required String Function(T) idOf,
  required String Function(T) nameOf,
  required void Function(String id) delete,
  required String label,
}) {
  final target = items.where((item) => nameOf(item) == name).firstOrNull;
  if (target == null) {
    return (false, 'No encontré ninguna $label llamada "$name".');
  }
  delete(idOf(target));
  return (true, 'Eliminé la $label "$name".');
}

List<String> _stringList(Object? value) =>
    (value as List?)?.cast<String>() ?? const [];

List<WorkflowStep> _parseToolSteps(Object? value) {
  final rawSteps = (value as List?)?.cast<Map<String, Object?>>() ?? const [];
  return [
    for (final step in rawSteps)
      WorkflowStep(
        id: generateUuidV4(),
        title: step['title'] as String? ?? '',
        role: step['role'] as String? ?? '',
        instruction: step['instruction'] as String? ?? '',
      ),
  ];
}
