part of '../assistant_mcp_server.dart';

/// Runs one tool call for [agentId]'s conversation and appends a live trace
/// line to that thread BEFORE returning the result to the model — the
/// point of using a real tool instead of a text block: this line appears
/// the moment the call happens, not as a summary once the whole turn ends.
Future<CallToolResult> dispatchKeelAiTool(
  String agentId,
  CallToolRequest request,
) async {
  // The sync tools are genuinely async (git over the network) — handled
  // before the synchronous switch.
  if (request.name == 'update_knowledge') {
    final message = await KnowledgeService.instance.notifier.update();
    AgentsService.instance.notifier.appendSystemNote(agentId, message);
    return CallToolResult(
      content: [
        TextContent(text: jsonEncode({'ok': true, 'message': message})),
      ],
    );
  }

  if (request.name == 'export_catalog' || request.name == 'refresh_catalog') {
    final sync = CatalogSyncService.instance.notifier;
    final message = request.name == 'export_catalog'
        ? await sync.exportCatalog()
        : await sync.refreshCatalog();
    AgentsService.instance.notifier.appendSystemNote(agentId, message);
    return CallToolResult(
      content: [
        TextContent(text: jsonEncode({'ok': true, 'message': message})),
      ],
    );
  }

  final (ok, message) = _runKeelAiTool(agentId, request);
  AgentsService.instance.notifier.appendSystemNote(agentId, message);
  return CallToolResult(
    content: [TextContent(text: jsonEncode({'ok': ok, 'message': message}))],
    isError: !ok,
  );
}

(bool, String) _runKeelAiTool(String agentId, CallToolRequest request) {
  final arguments = request.arguments ?? const <String, Object?>{};
  switch (request.name) {
    case 'create_skill':
      final result = executeSkillAction(
        CreateSkillAction(
          name: arguments['name'] as String,
          content: arguments['content'] as String,
          isGlobal: arguments['global'] as bool? ?? false,
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

    case 'create_tool':
      final result = executeToolAction(
        CreateToolAction(
          name: arguments['name'] as String,
          description: arguments['description'] as String,
          runtimeAlias: arguments['runtime'] as String,
          code: arguments['code'] as String,
          timeoutSeconds: (arguments['timeout_seconds'] as num?)?.toInt(),
          secretNames: _stringList(arguments['secret_names']),
        ),
      );
      return (result.ok, result.message);

    case 'request_secret':
      final requesterProfileId = AgentsService.instance.notifier.data.agents
          .where((agent) => agent.id == agentId)
          .firstOrNull
          ?.profileId;
      final message = SecretsService.instance.notifier.requestSecret(
        name: arguments['name'] as String,
        why: arguments['why'] as String,
        requestedByProfileId: requesterProfileId,
      );
      return (true, message);

    case 'register_mcp_server':
      final name = arguments['name'] as String;
      final transport = McpTransport.tryFromAlias(
        arguments['transport'] as String,
      );
      if (transport == null) {
        return (false, 'Transporte inválido — usá "stdio" o "http".');
      }
      final viewmodel = McpServersService.instance.notifier;
      final existing = viewmodel.data.servers
          .where((server) => server.name == name)
          .firstOrNull;
      final env = (arguments['env'] as Map?)?.cast<String, String>() ?? {};
      final secretEnv =
          (arguments['secret_env'] as Map?)?.cast<String, String>() ?? {};
      final args = _stringList(arguments['args']);
      final command = arguments['command'] as String? ?? '';
      final url = arguments['url'] as String? ?? '';
      final headers =
          (arguments['headers'] as Map?)?.cast<String, String>() ?? {};
      final error = existing == null
          ? viewmodel.createServer(
              name: name,
              transport: transport,
              command: command,
              args: args,
              env: env,
              secretEnv: secretEnv,
              url: url,
              headers: headers,
            )
          : viewmodel.updateServer(
              existing.id,
              name: name,
              transport: transport,
              command: command,
              args: args,
              env: env,
              secretEnv: secretEnv,
              url: url,
              headers: headers,
            );
      if (error != null) return (false, error);
      final pendingSecrets = SecretsService.instance.notifier.pendingOf(
        secretEnv.values.toList(),
      );
      final suffix = pendingSecrets.isEmpty
          ? ''
          : ' Ojo: secrets pendientes de valor: ${pendingSecrets.join(', ')}.';
      return (
        true,
        existing == null
            ? 'Registré el MCP "$name".$suffix'
            : 'Actualicé el MCP "$name".$suffix',
      );

    case 'delete_mcp_server':
      return _deleteByName(
        name: arguments['name'] as String,
        items: McpServersService.instance.notifier.data.servers,
        idOf: (server) => server.id,
        nameOf: (server) => server.name,
        delete: McpServersService.instance.notifier.deleteServer,
        label: 'integración MCP',
      );

    case 'list_secret_names':
      final secrets = SecretsService.instance.notifier.data.secrets;
      if (secrets.isEmpty) return (true, 'No hay secrets registrados.');
      final lines = [
        for (final secret in secrets)
          '- ${secret.name}'
              '${secret.isPending ? ' (PENDIENTE de valor)' : ''}',
      ];
      return (true, 'Secrets registrados:\n${lines.join('\n')}');

    case 'create_or_update_agent':
      final result = executeAgentAction(
        CreateAgentAction(
          handle: arguments['handle'] as String,
          role: arguments['role'] as String?,
          purpose: arguments['purpose'] as String?,
          instructions: arguments['instructions'] as String?,
          skillNames: _stringList(arguments['skill_names']),
          ruleNames: _stringList(arguments['rule_names']),
          toolNames: _stringList(arguments['tool_names']),
          mcpServerNames: _stringList(arguments['mcp_server_names']),
          providerAlias: arguments['provider'] as String?,
          systemBuilder: arguments['system_builder'] as bool?,
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

    case 'delete_tool':
      return _deleteByName(
        name: arguments['name'] as String,
        items: ToolsService.instance.notifier.data.tools,
        idOf: (tool) => tool.id,
        nameOf: (tool) => tool.name,
        delete: ToolsService.instance.notifier.deleteTool,
        label: 'tool',
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
