part of '../assistant_mcp_server.dart';

/// Runs one tool call for [agentId]'s conversation and appends a live trace
/// line to that thread BEFORE returning the result to the model — the
/// point of using a real tool instead of a text block: this line appears
/// the moment the call happens, not as a summary once the whole turn ends.
Future<CallToolResult> dispatchKeelAiTool(
  String agentId,
  CallToolRequest request,
) async {
  // Keel AI reads and mutates the live typed catalogs. A first tool call can
  // arrive while startup is still loading them; reading at that point would
  // expose a partial inventory and writing could overwrite persisted state
  // from an empty in-memory snapshot.
  await awaitCatalogsReady();

  // The sync tools are genuinely async (git over the network) — handled
  // before the synchronous switch.
  if (request.name == 'sync_knowledge') {
    final knowledge = KnowledgeService.instance.notifier;
    final baseName = (request.arguments?['base'] as String?)?.trim();
    final target = baseName == null || baseName.isEmpty
        ? null
        : knowledge.baseByName(baseName);
    final message = baseName == null || baseName.isEmpty
        ? await knowledge.syncAll()
        : target == null
        ? 'No existe la base de saber "$baseName".'
        : await knowledge.syncBase(target.id);
    AgentsService.instance.notifier.appendSystemNote(agentId, message);
    return CallToolResult(
      content: [
        TextContent(text: jsonEncode({'ok': true, 'message': message})),
      ],
    );
  }

  if (request.name == 'backup_system') {
    final vault = SystemVaultService.instance.notifier;
    final message = await _runVaultTool(vault, request);
    AgentsService.instance.notifier.appendSystemNote(agentId, message);
    return CallToolResult(
      content: [
        TextContent(text: jsonEncode({'ok': true, 'message': message})),
      ],
    );
  }

  if (request.name == 'restore_system') {
    final guarded = await _guardLockedCatalogMutation(agentId, request);
    final (ok, message) =
        guarded ??
        (
          true,
          await _runVaultTool(SystemVaultService.instance.notifier, request),
        );
    AgentsService.instance.notifier.appendSystemNote(agentId, message);
    return CallToolResult(
      content: [
        TextContent(text: jsonEncode({'ok': ok, 'message': message})),
      ],
      isError: !ok,
    );
  }

  final target = _lockedTargetOf(request);
  final guarded = await _guardLockedCatalogMutation(agentId, request);
  final (ok, message) = guarded ?? await _runKeelAiTool(agentId, request);
  final renamedTo = _renamedTargetName(request);
  if (ok && target != null && renamedTo != null) {
    await CatalogLocksService.instance.notifier.rename(
      target.kind,
      from: target.name,
      to: renamedTo,
    );
  }
  // La nota de sistema existe para dejar rastro de lo que CAMBIÓ. Una tool
  // de lectura no cambia nada: su respuesta ya viaja al modelo por el
  // resultado, y ponerla además en el hilo solo ensucia la conversación.
  if (!_readOnlyTools.contains(request.name)) {
    AgentsService.instance.notifier.appendSystemNote(agentId, message);
  }
  return CallToolResult(
    content: [
      TextContent(text: jsonEncode({'ok': ok, 'message': message})),
    ],
    isError: !ok,
  );
}

/// Tools that only read. No mutation, no trace line in the thread.
const _readOnlyTools = {
  'list_catalog',
  'list_workflows',
  'list_projects',
  'list_mcp_catalog',
  'list_secret_names',
  'get_item',
  'describe_system',
  'list_locked_items',
  'list_project_sessions',
  'read_session_thread',
  'resolve_message_reference',
  'inspect_session',
  'lint_workflow',
};

typedef _LockedTarget = ({CatalogLockKind kind, String name});

/// A locked item is never mutated until its caller has declared why and the
/// person using Keel has approved this exact request. The registry itself is
/// initialized locked, so `lock_item` and `unlock_item` follow this path too.
Future<(bool, String)?> _guardLockedCatalogMutation(
  String agentId,
  CallToolRequest request,
) async {
  final target = _lockedTargetOf(request);
  if (target == null ||
      !CatalogLocksService.instance.notifier.isLocked(
        target.kind,
        target.name,
      )) {
    return null;
  }
  final arguments = request.arguments ?? const <String, Object?>{};
  final intent = (arguments['change_intent'] as String? ?? '').trim();
  final reason = (arguments['change_reason'] as String? ?? '').trim();
  if (intent.isEmpty || reason.isEmpty) {
    final missing = [
      if (intent.isEmpty) 'change_intent',
      if (reason.isEmpty) 'change_reason',
    ].join(' y ');
    return (false, 'No escribí: falta declarar $missing.');
  }
  // Esta llamada NO vuelve hasta que la persona conteste, y no tiene plazo:
  // la tool queda suspendida a propósito, así el agente no sigue como si
  // hubiera escrito. Lo único que la termina sin respuesta es que se detenga
  // el turno.
  final outcome = await AgentsService.instance.notifier
      .requestCatalogChangePermission(
        agentId: agentId,
        kind: target.kind.alias,
        name: target.name,
        intent: intent,
        reason: reason,
      );

  // Cada final le pide otra cosa a quien lo lee, y por eso son mensajes
  // distintos: con un «no», insistir es desobedecer; con un turno cancelado
  // el pedido nunca se miró; y con otro permiso en cola hay que esperar y
  // volver. Decirlos juntos dejaba al agente eligiendo mal en los tres casos.
  return switch (outcome) {
    CatalogPermissionOutcome.approved => null,
    CatalogPermissionOutcome.denied => (
      false,
      'No escribí: rechazaste el cambio sobre ese elemento bloqueado. No lo '
          'reintentes: si creés que hace falta, decilo y esperá.',
    ),
    CatalogPermissionOutcome.cancelled => (
      false,
      'No escribí: se detuvo el turno antes de que contestaras. El elemento '
          'sigue bloqueado y sin tocar.',
    ),
    CatalogPermissionOutcome.busy => (
      false,
      'No escribí: ya hay otro permiso esperando respuesta en este chat. '
          'Solo se puede atender uno a la vez — esperá a que se resuelva y '
          'volvé a pedirlo.',
    ),
  };
}

_LockedTarget? _lockedTargetOf(CallToolRequest request) {
  final arguments = request.arguments ?? const <String, Object?>{};
  String value(String key) => (arguments[key] as String? ?? '').trim();
  CatalogLockKind? kind;
  String name;
  switch (request.name) {
    case 'create_skill' || 'update_skill' || 'delete_skill':
      kind = CatalogLockKind.skill;
      name = value('name');
    case 'create_rule' || 'update_rule' || 'delete_rule':
      kind = CatalogLockKind.rule;
      name = value('name');
    case 'create_tool' || 'update_tool' || 'delete_tool':
      kind = CatalogLockKind.tool;
      name = value('name');
    case 'create_hook' || 'set_hook_enabled' || 'delete_hook':
      kind = CatalogLockKind.hook;
      name = value('name');
    case 'create_or_update_agent' || 'delete_agent' || 'unassign_from_agent':
      kind = CatalogLockKind.agent;
      name = value('handle');
    case 'create_workflow' || 'update_workflow' || 'delete_workflow':
      kind = CatalogLockKind.workflow;
      name = value('name');
    case 'create_project' || 'update_project' || 'delete_project':
      kind = CatalogLockKind.project;
      name = value('name');
    case 'register_mcp_server' || 'delete_mcp_server':
      kind = CatalogLockKind.mcpServer;
      name = value('name');
    case 'install_mcp_integration':
      final entry = mcpCatalogEntryFor(value('catalog_id'));
      if (entry == null) return null;
      kind = CatalogLockKind.mcpServer;
      name = entry.serverName;
    case 'create_knowledge_base' ||
        'update_knowledge_base' ||
        'delete_knowledge_base':
      kind = CatalogLockKind.knowledgeBase;
      name = value('name');
    case 'request_secret':
      kind = CatalogLockKind.secret;
      name = value('name');
    case 'lock_item' || 'unlock_item' || 'restore_system':
      kind = CatalogLockKind.lockRegistry;
      name = kCatalogLockRegistryName;
    default:
      return null;
  }
  return name.isEmpty ? null : (kind: kind, name: name);
}

String? _renamedTargetName(CallToolRequest request) {
  switch (request.name) {
    case 'update_skill':
    case 'update_rule':
    case 'update_tool':
    case 'update_workflow':
    case 'update_project':
    case 'update_knowledge_base':
      final name = (request.arguments?['new_name'] as String? ?? '').trim();
      return name.isEmpty ? null : name;
    default:
      return null;
  }
}

Future<(bool, String)> _runKeelAiTool(
  String agentId,
  CallToolRequest request,
) async {
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

    case 'create_hook':
      return _upsertHook(arguments);

    case 'set_hook_enabled':
      return _setHookEnabled(arguments);

    case 'delete_hook':
      return _deleteHook(arguments['name'] as String);

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

    case 'list_mcp_catalog':
      return (true, _describeMcpCatalog());

    case 'install_mcp_integration':
      final catalogId = (arguments['catalog_id'] as String).trim();
      final entry = mcpCatalogEntryFor(catalogId);
      if (entry == null) {
        return (
          false,
          'No hay ninguna ficha con id "$catalogId". Mirá list_mcp_catalog; '
              'si el servidor que querés no está, registralo con '
              'register_mcp_server usando la configuración de SU documentación.',
        );
      }
      final servers = McpServersService.instance.notifier;
      final existed = servers.serverNamed(entry.serverName) != null;
      final installError = servers.installFromCatalog(entry);
      if (installError != null) return (false, installError);

      final faltan = [
        ...SecretsService.instance.notifier.pendingOf(entry.secretNames),
        ...SecretsService.instance.notifier.missingOf(entry.secretNames),
      ];
      final pedido = faltan.isEmpty
          ? ''
          : ' Falta que el usuario cargue en Secrets: ${faltan.join(', ')}.';
      final aviso = entry.note.isEmpty ? '' : ' ${entry.note}';
      return (
        true,
        '${existed ? "Actualicé" : "Instalé"} "${entry.serverName}" '
            '(${entry.name}). Para que un agente la use hay que asignársela '
            'con create_or_update_agent (mcp_server_names).$pedido$aviso',
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

    case 'list_catalog':
      final kind = (arguments['kind'] as String?)?.trim() ?? 'all';
      return (true, _describeCatalog(kind));

    case 'list_workflows':
      return (
        true,
        _catalogInspector().describeWorkflows(
          names: _stringList(arguments['names']),
        ),
      );

    case 'list_projects':
      return (
        true,
        _catalogInspector().describeProjects(
          names: _stringList(arguments['names']),
        ),
      );

    case 'get_item':
      return _getItem(
        (arguments['kind'] as String).trim().toLowerCase(),
        (arguments['name'] as String).trim(),
      );

    case 'list_locked_items':
      final locks = CatalogLocksService.instance.notifier.data.locks;
      return (
        true,
        locks.map((entry) => '${entry.kind.alias}:${entry.name}').join('\n'),
      );

    case 'lock_item':
    case 'unlock_item':
      final kind = CatalogLockKind.tryFromAlias(
        arguments['kind'] as String? ?? '',
      );
      final name = (arguments['name'] as String? ?? '').trim();
      if (kind == null || name.isEmpty) {
        return (false, 'Indicá un kind válido y un name no vacío.');
      }
      await CatalogLocksService.instance.notifier.setLocked(
        kind,
        name,
        locked: request.name == 'lock_item',
      );
      return (
        true,
        request.name == 'lock_item'
            ? 'Bloqueé ${kind.alias} "$name".'
            : 'Desbloqueé ${kind.alias} "$name".',
      );

    case 'describe_system':
      return (true, _describeSystem());

    case 'update_skill':
      final skills = SkillsService.instance.notifier;
      final skill = skills.data.skills
          .where((entry) => entry.name == arguments['name'])
          .firstOrNull;
      if (skill == null) {
        return (false, 'No existe la skill "${arguments['name']}".');
      }
      final error = skills.updateSkill(
        skill.id,
        name: (arguments['new_name'] as String?)?.trim().isNotEmpty ?? false
            ? (arguments['new_name'] as String).trim()
            : skill.name,
        content: arguments['content'] as String,
      );
      return (error == null, error ?? 'Actualicé la skill "${skill.name}".');

    case 'update_rule':
      final rules = RulesService.instance.notifier;
      final rule = rules.data.rules
          .where((entry) => entry.name == arguments['name'])
          .firstOrNull;
      if (rule == null) {
        return (false, 'No existe la regla "${arguments['name']}".');
      }
      final error = rules.updateRule(
        rule.id,
        name: (arguments['new_name'] as String?)?.trim().isNotEmpty ?? false
            ? (arguments['new_name'] as String).trim()
            : rule.name,
        content: arguments['content'] as String,
      );
      return (error == null, error ?? 'Actualicé la regla "${rule.name}".');

    case 'update_tool':
      final tools = ToolsService.instance.notifier;
      final tool = tools.data.tools
          .where((entry) => entry.name == arguments['name'])
          .firstOrNull;
      if (tool == null) {
        return (false, 'No existe la tool "${arguments['name']}".');
      }
      // Lo que no venga queda como estaba: el update del VM pide todos los
      // campos, pero el modelo puede querer tocar uno solo.
      final runtimeAlias = arguments['runtime'] as String?;
      final error = tools.updateTool(
        tool.id,
        name: (arguments['new_name'] as String?)?.trim().isNotEmpty ?? false
            ? (arguments['new_name'] as String).trim()
            : tool.name,
        description: arguments['description'] as String? ?? tool.description,
        runtime: runtimeAlias == null
            ? tool.runtime
            : ToolRuntime.tryFromAlias(runtimeAlias) ?? tool.runtime,
        code: arguments['code'] as String? ?? tool.code,
        timeoutSeconds:
            arguments['timeout_seconds'] as int? ?? tool.timeoutSeconds,
        secretNames: arguments['secret_names'] == null
            ? tool.secretNames
            : _stringList(arguments['secret_names']),
      );
      return (error == null, error ?? 'Actualicé la tool "${tool.name}".');

    case 'update_workflow':
      final workflows = WorkflowsService.instance.notifier;
      final workflow = workflows.data.workflows
          .where((entry) => entry.name == arguments['name'])
          .firstOrNull;
      if (workflow == null) {
        return (false, 'No existe el workflow "${arguments['name']}".');
      }
      final requestedKind = arguments['kind'] as String?;
      final kind = requestedKind == null
          ? workflow.kind
          : WorkflowKind.values.firstWhere(
              (entry) => entry.name == requestedKind,
              orElse: () => workflow.kind,
            );
      final resolutionRole =
          arguments['resolution_role'] as String? ??
          workflow.policy.resolutionRole;
      final qualityGates = arguments['quality_gates'] == null
          ? workflow.policy.qualityGates
          : _workflowQualityGates(arguments['quality_gates']);
      final error = workflows.updateWorkflow(
        workflow.id,
        name: (arguments['new_name'] as String?)?.trim().isNotEmpty ?? false
            ? (arguments['new_name'] as String).trim()
            : workflow.name,
        whenToApply:
            arguments['when_to_apply'] as String? ?? workflow.whenToApply,
        kind: kind,
        policy: workflow.policy.copyWith(
          resolutionRole: resolutionRole,
          requiredSkillNames: arguments['skills'] == null
              ? null
              : _stringList(arguments['skills']),
          requiredRuleNames: arguments['rule_names'] == null
              ? null
              : _stringList(arguments['rule_names']),
          requiredKnowledgeBaseNames: arguments['knowledge_base_names'] == null
              ? null
              : _stringList(arguments['knowledge_base_names']),
          qualityGates: qualityGates,
          maxReplans: _boundedReplanLimit(arguments['max_replans']),
          maxSubagents: _boundedSubagentLimit(arguments['max_subagents']),
          maxReviewCycles: _boundedReviewCycles(arguments['max_review_cycles']),
          idleTimeoutMinutes: _boundedIdleTimeout(
            arguments['idle_timeout_minutes'],
          ),
          nodeTimeoutMinutes: _boundedNodeTimeout(
            arguments['node_timeout_minutes'],
          ),
        ),
        skillNames: arguments['skills'] == null
            ? null
            : _stringList(arguments['skills']),
        buildsRoadmap: arguments['builds_roadmap'] as bool?,
        capabilities: _workflowCapabilities(arguments['capabilities']),
      );
      return (
        error == null,
        error ?? 'Actualicé el workflow "${workflow.name}" (${kind.name}).',
      );

    case 'unassign_from_agent':
      return _unassignFromAgent(
        handle: (arguments['handle'] as String).trim(),
        skills: _stringList(arguments['skill_names']),
        rules: _stringList(arguments['rule_names']),
        hooks: _stringList(arguments['hook_names']),
        tools: _stringList(arguments['tool_names']),
        mcpServers: _stringList(arguments['mcp_server_names']),
        knowledgeBases: _stringList(arguments['knowledge_base_names']),
      );

    case 'update_project':
      return _updateProject(arguments);

    case 'open_project_session':
      return _openProjectSession(
        project: (arguments['project'] as String).trim(),
        prompt: (arguments['prompt'] as String).trim(),
      );

    case 'list_project_sessions':
      return _listProjectSessions((arguments['project'] as String).trim());

    case 'read_session_thread':
      return _readSessionThread(
        project: (arguments['project'] as String).trim(),
        session: (arguments['session'] as String? ?? '').trim(),
        limit: (arguments['limit'] as num?)?.toInt() ?? 40,
      );

    case 'resolve_message_reference':
      return _resolveMessageReference(
        (arguments['reference'] as String? ?? '').trim(),
      );

    case 'reply_in_session':
      return _replyInSession(
        rawReference: (arguments['reference'] as String? ?? '').trim(),
        text: (arguments['text'] as String? ?? '').trim(),
      );

    case 'inspect_session':
      return _inspectSession(
        project: (arguments['project'] as String? ?? '').trim(),
        session: (arguments['session'] as String? ?? '').trim(),
        full: arguments['full'] as bool? ?? false,
      );

    case 'intervene':
      return _intervene(
        project: (arguments['project'] as String? ?? '').trim(),
        session: (arguments['session'] as String? ?? '').trim(),
        text: (arguments['text'] as String? ?? '').trim(),
      );

    case 'answer_decision':
      return _answerDecision(
        project: (arguments['project'] as String? ?? '').trim(),
        session: (arguments['session'] as String? ?? '').trim(),
        decisionId: (arguments['decision_id'] as String? ?? '').trim(),
        answer: (arguments['answer'] as String? ?? '').trim(),
        approve: arguments['approve'] as bool?,
        scope: (arguments['scope'] as String? ?? 'once').trim(),
      );

    case 'lint_workflow':
      return _lintWorkflow(arguments['capabilities']);

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
          hookNames: _stringList(arguments['hook_names']),
          knowledgeBaseNames: _stringList(arguments['knowledge_base_names']),
          providerAlias: arguments['provider'] as String?,
          model: arguments['model'] as String?,
          effort: arguments['effort'] as String?,
          systemBuilder: arguments['system_builder'] as bool?,
        ),
      );
      return (result.ok, result.message);

    case 'create_workflow':
      final rawKind = arguments['kind'] as String?;
      final result = executeWorkflowAction(
        CreateWorkflowAction(
          name: arguments['name'] as String,
          whenToApply: arguments['when_to_apply'] as String? ?? '',
          kind: WorkflowKind.values.firstWhere(
            (kind) => kind.name == rawKind,
            orElse: () => WorkflowKind.general,
          ),
          resolutionRole: arguments['resolution_role'] as String? ?? '',
          skillNames: _stringList(arguments['skills']),
          requiredRuleNames: _stringList(arguments['rule_names']),
          requiredKnowledgeBaseNames: _stringList(
            arguments['knowledge_base_names'],
          ),
          qualityGates: _workflowQualityGates(arguments['quality_gates']),
          maxReplans: _boundedReplanLimit(arguments['max_replans']),
          maxSubagents: _boundedSubagentLimit(arguments['max_subagents']),
          maxReviewCycles: _boundedReviewCycles(arguments['max_review_cycles']),
          capabilities:
              _workflowCapabilities(arguments['capabilities']) ?? const [],
          buildsRoadmap: arguments['builds_roadmap'] as bool?,
        ),
      );
      return (result.ok, result.message);

    case 'create_project':
      final result = executeProjectAction(
        CreateProjectAction(
          name: arguments['name'] as String,
          purpose: arguments['purpose'] as String? ?? '',
          workingDirectory: arguments['working_directory'] as String? ?? '',
          agentHandles: _stringList(arguments['agent_handles']),
          workflowNames: _stringList(arguments['workflow_names']),
          ruleNames: _stringList(arguments['rule_names']),
          hookNames: _stringList(arguments['hook_names']),
          knowledgeBaseNames: _stringList(arguments['knowledge_base_names']),
          maintained: arguments['maintained'] as bool? ?? true,
        ),
      );
      return (result.ok, result.message);

    case 'create_knowledge_base':
      return _createKnowledgeBase(arguments);

    case 'update_knowledge_base':
      return _updateKnowledgeBase(arguments);

    case 'delete_knowledge_base':
      return _deleteByName(
        name: arguments['name'] as String,
        items: KnowledgeService.instance.notifier.data.bases,
        idOf: (base) => base.id,
        nameOf: (base) => base.name,
        delete: KnowledgeService.instance.notifier.deleteBase,
        label: 'base de saber',
      );

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
        delete: workflowDeletionService.deleteWorkflow,
        label: 'workflow',
      );

    case 'delete_project':
      return _deleteByName(
        name: arguments['name'] as String,
        items: ProjectsService.instance.notifier.data.projects,
        idOf: (project) => project.id,
        nameOf: (project) => project.name,
        delete: ProjectsService.instance.notifier.deleteProject,
        label: 'proyecto',
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

/// What already exists in the system, so the model references real names
/// instead of inventing them. Read-only: leaves no trace line in the thread
/// (see the read-only set in `dispatchKeelAiTool`).
String _describeCatalog(String kind) {
  final wanted = kind.isEmpty ? 'all' : kind.toLowerCase();
  final sections = <String>[];

  void section(String key, String title, List<String> lines) {
    if (wanted != 'all' && wanted != key) return;
    sections.add(
      lines.isEmpty
          ? '$title: (ninguno registrado)'
          : '$title (${lines.length}):\n${lines.join('\n')}',
    );
  }

  section('skills', 'Skills', [
    for (final skill in SkillsService.instance.notifier.data.skills)
      '- ${skill.name} — ${_firstLine(skill.content)}',
  ]);

  section('rules', 'Reglas', [
    for (final rule in RulesService.instance.notifier.data.rules)
      '- ${rule.name} — ${_firstLine(rule.content)}',
  ]);

  section('hooks', 'Hooks', [
    for (final hook in HooksService.instance.notifier.data.hooks)
      '- ${hook.name} (${hook.event.alias}; '
          '${hook.enabled ? 'activo' : 'apagado'}) — '
          '${_firstLine(hook.description)}',
  ]);

  section('tools', 'Tools', [
    for (final tool in ToolsService.instance.notifier.data.tools)
      '- ${tool.name} (${tool.runtime.alias}) — '
          '${_firstLine(tool.description)}',
  ]);

  section('agents', 'Agentes', [
    for (final profile in AgentProfilesService.instance.notifier.data.profiles)
      // El perfil reservado del asistente no se asigna ni se edita desde acá.
      if (profile.name != kKeelAiHandle)
        '- @${profile.name} — ${profile.role}'
            '${profile.skills.isEmpty ? '' : ' | skills: ${profile.skills.join(', ')}'}',
  ]);

  section('workflows', 'Workflows', [
    for (final workflow in WorkflowsService.instance.notifier.data.workflows)
      '- ${workflow.name} (${workflow.kind.name}; dueño: '
          '${workflow.policy.resolutionRole.isEmpty ? 'auto' : workflow.policy.resolutionRole}) — '
          '${_firstLine(workflow.whenToApply)}',
  ]);

  section('projects', 'Proyectos', [
    for (final project in ProjectsService.instance.notifier.data.projects)
      '- ${project.name}${project.maintained ? '' : ' [solo lectura]'} — '
          '${_firstLine(project.purpose)}',
  ]);

  section('requirements', 'Requerimientos internos', [
    for (final requirement
        in RequirementsService.instance.notifier.data.requirements)
      '- ${requirement.code} ${requirement.title} '
          '(${requirement.status.label.toLowerCase()})',
  ]);

  section('mcp_servers', 'MCPs externos', [
    for (final server in McpServersService.instance.notifier.data.servers)
      '- ${server.name} (${server.transport.alias}) — '
          '${server.detail}',
  ]);

  final knowledge = KnowledgeService.instance.notifier;
  section('knowledge_bases', 'Bases de saber', [
    for (final base in knowledge.data.bases)
      '- ${base.name} (${knowledge.indexOf(base.id)?.documentCount ?? 0} '
          'documentos) — ${_firstLine(base.description)}',
  ]);

  if (sections.isEmpty) {
    return 'No conozco el tipo "$kind". Válidos: skills, rules, tools, '
        'agents, workflows, projects, hooks, mcp_servers, '
        'knowledge_bases, all.';
  }
  return sections.join('\n\n');
}

(bool, String) _createKnowledgeBase(Map<String, Object?> arguments) {
  final knowledge = KnowledgeService.instance.notifier;
  final name = (arguments['name'] as String).trim();
  final source = KnowledgeSource.tryFromAlias(
    (arguments['source'] as String? ?? '').trim().toLowerCase(),
  );
  if (source == null) {
    return (false, 'La fuente tiene que ser "local" o "git".');
  }

  final localPath = (arguments['local_path'] as String? ?? '').trim();
  if (source == KnowledgeSource.local && localPath.isEmpty) {
    return (false, 'Una base local necesita la ruta de su carpeta.');
  }

  final error = knowledge.createBase(
    name: name,
    description: arguments['description'] as String? ?? '',
    source: source,
    gitUrl: (arguments['git_url'] as String? ?? '').trim(),
    gitBranch: (arguments['git_branch'] as String? ?? '').trim(),
    localPath: localPath,
    // La arma un agente para escribir adentro: la carpeta todavía no existe.
    createFolderIfMissing: true,
  );
  if (error != null) return (false, error);

  final base = knowledge.baseByName(name);
  final root = base == null ? '' : knowledge.rootPathOf(base);
  return (
    true,
    source == KnowledgeSource.local
        ? 'Registré la base de saber "$name" en $root. Escribí sus '
              'documentos ahí (empezá por INDEX.md, que es la portada que '
              'reciben los agentes) y asignásela a un proyecto con '
              'update_project(knowledge_base_names).'
        : 'Registré la base de saber "$name". Corré sync_knowledge(base: '
              '"$name") para clonarla, y asignásela a un proyecto con '
              'update_project(knowledge_base_names).',
  );
}

(bool, String) _updateKnowledgeBase(Map<String, Object?> arguments) {
  final knowledge = KnowledgeService.instance.notifier;
  final name = (arguments['name'] as String).trim();
  final base = knowledge.baseByName(name);
  if (base == null) return (false, 'No existe la base de saber "$name".');

  final newName = (arguments['new_name'] as String?)?.trim();
  final sourceAlias = (arguments['source'] as String?)?.trim().toLowerCase();
  final source = sourceAlias == null || sourceAlias.isEmpty
      ? base.source
      : KnowledgeSource.tryFromAlias(sourceAlias);
  if (source == null) {
    return (false, 'La fuente tiene que ser "local" o "git".');
  }

  final error = knowledge.updateBase(
    base.id,
    name: newName == null || newName.isEmpty ? base.name : newName,
    description: arguments['description'] as String? ?? base.description,
    source: source,
    gitUrl: arguments['git_url'] as String? ?? base.gitUrl,
    gitBranch: arguments['git_branch'] as String? ?? base.gitBranch,
    localPath: arguments['local_path'] as String? ?? base.localPath,
  );
  if (error != null) return (false, error);
  return (true, 'Actualicé la base de saber "$name".');
}

/// El contenido COMPLETO de una cosa registrada. `list_catalog` da una
/// línea por item para decidir; esto da el texto entero para poder
/// actualizarlo sin pisar lo que había.
(bool, String) _getItem(String kind, String name) {
  switch (kind) {
    case 'skill':
      final skill = SkillsService.instance.notifier.data.skills
          .where((entry) => entry.name == name)
          .firstOrNull;
      if (skill == null) return (false, 'No existe la skill "$name".');
      return (true, 'Skill "${skill.name}":\n\n${skill.content}');

    case 'rule':
      final rule = RulesService.instance.notifier.data.rules
          .where((entry) => entry.name == name)
          .firstOrNull;
      if (rule == null) return (false, 'No existe la regla "$name".');
      return (true, 'Regla "${rule.name}":\n\n${rule.content}');

    case 'tool':
      final tool = ToolsService.instance.notifier.data.tools
          .where((entry) => entry.name == name)
          .firstOrNull;
      if (tool == null) return (false, 'No existe la tool "$name".');
      return (
        true,
        'Tool "${tool.name}" (${tool.runtime.alias}, '
            '${tool.timeoutSeconds}s)\n'
            'Descripción: ${tool.description}\n'
            'Secrets: ${tool.secretNames.isEmpty ? 'ninguno' : tool.secretNames.join(', ')}\n\n'
            '${tool.code}',
      );

    case 'agent':
      final handle = name.startsWith('@') ? name.substring(1) : name;
      final profile = AgentProfilesService.instance.notifier.data.profiles
          .where((entry) => entry.name == handle)
          .firstOrNull;
      if (profile == null) return (false, 'No existe el agente "@$handle".');
      return (true, _catalogInspector().describeAgent(profile));

    case 'workflow':
      final workflow = WorkflowsService.instance.notifier.data.workflows
          .where((entry) => entry.name == name)
          .firstOrNull;
      if (workflow == null) return (false, 'No existe el workflow "$name".');
      return (true, _catalogInspector().describeWorkflow(workflow));

    case 'project':
      final project = ProjectsService.instance.notifier.data.projects
          .where((entry) => entry.name == name)
          .firstOrNull;
      if (project == null) return (false, 'No existe el proyecto "$name".');
      return (true, _catalogInspector().describeProject(project));

    case 'hook':
      final hook = HooksService.instance.notifier.hookByName(name);
      if (hook == null) return (false, 'No existe el hook "$name".');
      final body = switch (hook.body) {
        HookCommand(:final command) => 'comando: $command',
        HookToolRef(:final toolName) => 'tool: $toolName',
      };
      return (
        true,
        'Hook "${hook.name}"\n'
            'ID: ${hook.id}\n'
            'Descripción: ${hook.description}\n'
            'Evento: ${hook.event.alias}\n'
            'Matcher: ${_orMissing(hook.matcher)}\n'
            'Cuerpo: $body\n'
            'Timeout: ${hook.timeoutSeconds}s\n'
            'Reglas que garantiza: ${_orNone(hook.enforces)}\n'
            'Global: ${hook.isGlobal ? 'sí' : 'no'}\n'
            'Activo: ${hook.enabled ? 'sí' : 'no'}',
      );

    case 'knowledge_base':
      final knowledge = KnowledgeService.instance.notifier;
      final base = knowledge.baseByName(name);
      if (base == null) return (false, 'No existe la base de saber "$name".');
      final index = knowledge.indexOf(base.id);
      return (
        true,
        'Base de saber "${base.name}" (${base.source.alias})\n'
            'Descripción: ${base.description}\n'
            'Raíz: ${knowledge.rootPathOf(base)}\n'
            'Documentos: ${index?.documentCount ?? 0}\n'
            '${index == null || index.problem.isEmpty ? '' : 'Problema: ${index.problem}\n'}'
            'Usada por proyectos: '
            '${_orNone([for (final project in ProjectsService.instance.notifier.data.projects)
              if (project.knowledgeBaseNames.contains(base.name)) project.name])}',
      );

    case 'secret':
      final secret = SecretsService.instance.notifier.data.secrets
          .where((entry) => entry.name == name)
          .firstOrNull;
      if (secret == null) return (false, 'No existe el secret "$name".');
      return (
        true,
        'Secret "${secret.name}"\n'
            'Descripción: ${_orMissing(secret.description)}\n'
            'Estado: ${secret.isPending ? 'pendiente de valor' : 'configurado'}\n'
            'El valor nunca se expone.',
      );

    case 'board':
      final parts = name.split(' · ');
      if (parts.length != 2) {
        return (false, 'El tablero se identifica como "proyecto · tablero".');
      }
      final project = ProjectsService.instance.notifier.data.projects
          .where((entry) => entry.name == parts.first)
          .firstOrNull;
      final board = project == null
          ? null
          : BoardsService.instance.notifier.boardNamed(project.id, parts.last);
      if (board == null) return (false, 'No existe el tablero "$name".');
      return (
        true,
        'Tablero "${catalogBoardLockName(project!.name, board.name)}"\n'
            'Nota: ${_orMissing(board.note)}\n'
            'Campos: ${board.fields.length}\n'
            'Acciones: ${board.actions.length}',
      );

    case 'lock_registry':
      if (name != kCatalogLockRegistryName) {
        return (false, 'El único registro es "$kCatalogLockRegistryName".');
      }
      final locks = CatalogLocksService.instance.notifier.data.locks;
      return (
        true,
        'Registro de candados (${locks.length}):\n'
            '${locks.map((entry) => '- ${entry.key}').join('\n')}',
      );

    case 'mcp_server':
      final server = McpServersService.instance.notifier.data.servers
          .where((entry) => entry.name == name)
          .firstOrNull;
      if (server == null) return (false, 'No existe el MCP "$name".');
      return (
        true,
        'MCP "${server.name}" (${server.transport.alias})\n'
            'Destino: ${server.detail}\n'
            'Env literales: ${server.env.isEmpty ? 'ninguna' : server.env.keys.join(', ')}\n'
            'Secrets: ${_orNone(server.secretNames)}',
      );

    default:
      return (
        false,
        'No conozco el tipo "$kind". Válidos: skill, rule, tool, agent, '
            'workflow, project, hook, mcp_server, knowledge_base, board, '
            'secret o lock_registry.',
      );
  }
}

KeelCatalogInspector _catalogInspector() => KeelCatalogInspector(
  profiles: AgentProfilesService.instance.notifier.data.profiles,
  workflows: WorkflowsService.instance.notifier.data.workflows,
  projects: ProjectsService.instance.notifier.data.projects,
  skillNames: {
    for (final skill in SkillsService.instance.notifier.data.skills) skill.name,
  },
  ruleNames: {
    for (final rule in RulesService.instance.notifier.data.rules) rule.name,
  },
  knowledgeBaseNames: {
    for (final base in KnowledgeService.instance.notifier.data.bases) base.name,
  },
  hookNames: {
    for (final hook in HooksService.instance.notifier.data.hooks) hook.name,
  },
);

String _orNone(List<String> values) =>
    values.isEmpty ? 'ninguno' : values.join(', ');

/// Crea o actualiza un hook desde una tool de Keel AI.
(bool, String) _upsertHook(Map<String, dynamic> arguments) {
  final name = arguments['name'] as String;
  final event = HookEvent.tryFromAlias(arguments['event'] as String? ?? '');
  if (event == null) {
    return (
      false,
      'Evento desconocido. Los que corren en los dos CLIs son: '
          '${HookEvent.values.where((entry) => entry.isPortable).map((entry) => entry.alias).join(', ')}.',
    );
  }

  final toolName = (arguments['tool_name'] as String? ?? '').trim();
  final command = (arguments['command'] as String? ?? '').trim();
  if (toolName.isEmpty && command.isEmpty) {
    return (false, 'Un hook necesita un command o un tool_name.');
  }
  final body = toolName.isNotEmpty
      ? HookToolRef(toolName)
      : HookCommand(command);

  final hooks = HooksService.instance.notifier;
  final existing = hooks.hookByName(name);
  final error = existing == null
      ? hooks.createHook(
          name: name,
          description: arguments['description'] as String? ?? '',
          event: event,
          body: body,
          matcher: arguments['matcher'] as String? ?? '',
          timeoutSeconds:
              arguments['timeout_seconds'] as int? ??
              kDefaultHookTimeoutSeconds,
          enforces:
              (arguments['enforces'] as List?)?.cast<String>() ?? const [],
          isGlobal: arguments['is_global'] as bool? ?? false,
          enabled: arguments['enabled'] as bool? ?? true,
        )
      : hooks.updateHook(
          existing.id,
          name: name,
          description: arguments['description'] as String? ?? '',
          event: event,
          body: body,
          matcher: arguments['matcher'] as String? ?? '',
          timeoutSeconds:
              arguments['timeout_seconds'] as int? ??
              kDefaultHookTimeoutSeconds,
          enforces:
              (arguments['enforces'] as List?)?.cast<String>() ?? const [],
          isGlobal: arguments['is_global'] as bool? ?? false,
          enabled: arguments['enabled'] as bool? ?? true,
        );
  if (error != null) return (false, error);

  final verb = existing == null ? 'Creé' : 'Actualicé';
  final scope = (arguments['is_global'] as bool? ?? false)
      ? ' Corre para todos los agentes.'
      : ' Falta asignárselo a un agente o a un proyecto.';
  return (true, '$verb el hook "$name" en ${event.label}.$scope');
}

(bool, String) _setHookEnabled(Map<String, dynamic> arguments) {
  final name = arguments['name'] as String;
  final enabled = arguments['enabled'] as bool;
  final hooks = HooksService.instance.notifier;
  final hook = hooks.hookByName(name);
  if (hook == null) return (false, 'No existe ningún hook "$name".');

  final error = hooks.setEnabled(hook.id, enabled);
  if (error != null) return (false, error);
  return (
    true,
    enabled
        ? 'Prendí el hook "$name".'
        : 'Apagué el hook "$name": lo que frenaba vuelve a poder pasar.',
  );
}

(bool, String) _deleteHook(String name) {
  final hooks = HooksService.instance.notifier;
  final hook = hooks.hookByName(name);
  if (hook == null) return (false, 'No existe ningún hook "$name".');

  final assignments = hooks.assignmentsOf(name);
  hooks.deleteHook(hook.id);
  return (
    true,
    'Eliminé el hook "$name" y lo saqué de ${assignments.profiles} '
        'agente(s) y ${assignments.projects} proyecto(es).',
  );
}

String _orMissing(String value) =>
    value.trim().isEmpty ? 'sin configurar' : value.trim();

/// Respaldar o restaurar el sistema entero desde una tool.
///
/// Restaurar acá aplica TODAS las secciones: el preview por secciones es una
/// pregunta para el usuario, y una tool no tiene a quién hacérsela. Por eso
/// primero lee —si no hay respaldo, devuelve eso y no toca nada.
Future<String> _runVaultTool(
  SystemVaultViewModel vault,
  CallToolRequest request,
) async {
  if (request.name == 'backup_system') return vault.backup();
  final read = await vault.inspectVault();
  if (vault.data.preview == null) return read;
  return vault.applyLoaded(sections: BackupSection.values.toSet());
}

/// Saca asignaciones de un agente. `create_or_update_agent` solo suma, así
/// que sin esto la única forma de corregir una asignación equivocada era
/// borrar el agente y rehacerlo — perdiendo su historial de conversación.
(bool, String) _unassignFromAgent({
  required String handle,
  required List<String> skills,
  required List<String> rules,
  required List<String> hooks,
  required List<String> tools,
  required List<String> mcpServers,
  required List<String> knowledgeBases,
}) {
  final cleanHandle = handle.startsWith('@') ? handle.substring(1) : handle;
  if (cleanHandle == kKeelAiHandle) {
    return (false, 'El perfil "@$cleanHandle" está reservado.');
  }

  final viewmodel = AgentProfilesService.instance.notifier;
  final profile = viewmodel.data.profiles
      .where((entry) => entry.name == cleanHandle)
      .firstOrNull;
  if (profile == null) return (false, 'No existe el agente "@$cleanHandle".');

  if (skills.isEmpty &&
      rules.isEmpty &&
      hooks.isEmpty &&
      tools.isEmpty &&
      mcpServers.isEmpty &&
      knowledgeBases.isEmpty) {
    return (false, 'No me dijiste qué sacarle a "@$cleanHandle".');
  }

  final error = viewmodel.updateProfile(
    profile.id,
    name: profile.name,
    role: profile.role,
    systemPrompt: profile.systemPrompt,
    skills: _without(profile.skills, skills),
    rules: _without(profile.rules, rules),
    hooks: _without(profile.hooks, hooks),
    tools: _without(profile.tools, tools),
    mcpServers: _without(profile.mcpServers, mcpServers),
    knowledgeBaseNames: _without(profile.knowledgeBaseNames, knowledgeBases),
    model: profile.model,
    effort: profile.effort,
  );
  if (error != null) return (false, error);

  final removed = [
    if (skills.isNotEmpty) 'skills: ${skills.join(', ')}',
    if (rules.isNotEmpty) 'reglas: ${rules.join(', ')}',
    if (hooks.isNotEmpty) 'hooks: ${hooks.join(', ')}',
    if (tools.isNotEmpty) 'tools: ${tools.join(', ')}',
    if (mcpServers.isNotEmpty) 'MCPs: ${mcpServers.join(', ')}',
    if (knowledgeBases.isNotEmpty)
      'bases de saber: ${knowledgeBases.join(', ')}',
  ];
  return (true, 'Le saqué a @$cleanHandle — ${removed.join(' | ')}.');
}

List<String> _without(List<String> current, List<String> removed) {
  final drop = removed.toSet();
  return current.where((entry) => !drop.contains(entry)).toList();
}

/// Actualiza un proyecto. Los miembros y workflows viajan por nombre y se
/// resuelven a ids acá; lo que no venga en los argumentos queda como estaba.
(bool, String) _updateProject(Map<String, Object?> arguments) {
  final projects = ProjectsService.instance.notifier;
  final name = (arguments['name'] as String).trim();
  final project = projects.data.projects
      .where((entry) => entry.name == name)
      .firstOrNull;
  if (project == null) return (false, 'No existe el proyecto "$name".');

  final profiles = AgentProfilesService.instance.notifier.data.profiles;
  final workflows = WorkflowsService.instance.notifier.data.workflows;
  final warnings = <String>[];

  var profileIds = project.profileIds;
  if (arguments['agent_handles'] != null) {
    profileIds = [];
    for (final handle in _stringList(arguments['agent_handles'])) {
      final clean = handle.startsWith('@') ? handle.substring(1) : handle;
      final id = profiles.where((p) => p.name == clean).firstOrNull?.id;
      if (id == null) {
        warnings.add('no encontré a @$clean');
      } else {
        profileIds.add(id);
      }
    }
  }

  var workflowIds = project.workflowIds;
  if (arguments['workflow_names'] != null) {
    workflowIds = [];
    for (final workflowName in _stringList(arguments['workflow_names'])) {
      final id = workflows.where((w) => w.name == workflowName).firstOrNull?.id;
      if (id == null) {
        warnings.add('no encontré el workflow $workflowName');
      } else {
        workflowIds.add(id);
      }
    }
  }

  var ruleNames = project.ruleNames;
  if (arguments['rule_names'] != null) {
    final rules = _keepKnownNames(
      _stringList(arguments['rule_names']),
      known: RulesService.instance.notifier.data.rules.map((rule) => rule.name),
    );
    ruleNames = rules.$1;
    if (rules.$2.isNotEmpty) {
      warnings.add('no encontré la regla ${rules.$2.join(', ')}');
    }
  }

  var knowledgeBaseNames = project.knowledgeBaseNames;
  if (arguments['knowledge_base_names'] != null) {
    final bases = _keepKnownNames(
      _stringList(arguments['knowledge_base_names']),
      known: KnowledgeService.instance.notifier.data.bases.map(
        (base) => base.name,
      ),
    );
    knowledgeBaseNames = bases.$1;
    if (bases.$2.isNotEmpty) {
      warnings.add('no encontré la base de saber ${bases.$2.join(', ')}');
    }
  }

  var hookNames = project.hookNames;
  if (arguments['hook_names'] != null) {
    final hooks = _keepKnownNames(
      _stringList(arguments['hook_names']),
      known: HooksService.instance.notifier.data.hooks.map((hook) => hook.name),
    );
    hookNames = hooks.$1;
    if (hooks.$2.isNotEmpty) {
      warnings.add('no encontré el hook ${hooks.$2.join(', ')}');
    }
  }

  final error = projects.updateProject(
    project.id,
    name: (arguments['new_name'] as String?)?.trim().isNotEmpty ?? false
        ? (arguments['new_name'] as String).trim()
        : project.name,
    purpose: arguments['purpose'] as String? ?? project.purpose,
    workingDirectory:
        arguments['working_directory'] as String? ?? project.workingDirectory,
    profileIds: profileIds,
    workflowIds: workflowIds,
    ruleNames: ruleNames,
    hookNames: hookNames,
    knowledgeBaseNames: knowledgeBaseNames,
    maintained: arguments['maintained'] as bool? ?? project.maintained,
  );
  if (error != null) return (false, error);

  // El workflow activo se setea después: tiene que estar entre los que
  // quedaron disponibles, cosa que recién se sabe con el update aplicado.
  final activeName = (arguments['active_workflow'] as String?)?.trim();
  if (activeName != null && activeName.isNotEmpty) {
    final active = workflows.where((w) => w.name == activeName).firstOrNull;
    if (active == null || !workflowIds.contains(active.id)) {
      warnings.add(
        'no pude activar "$activeName" (no está entre los disponibles)',
      );
    } else {
      projects.setActiveWorkflow(project.id, active.id);
    }
  }

  for (final raw in (arguments['member_engines'] as List?) ?? const []) {
    if (raw is! Map) continue;
    final data = raw.cast<String, Object?>();
    final handle = (data['handle'] as String? ?? '').trim();
    final profile = profiles
        .where((entry) => entry.name == handle && profileIds.contains(entry.id))
        .firstOrNull;
    if (profile == null) {
      warnings.add('no pude ajustar el motor de @$handle (no es miembro)');
      continue;
    }
    if (data['clear'] as bool? ?? false) {
      projects.clearMemberTuning(project.id, profile.id);
      continue;
    }
    final providerAlias = (data['provider'] as String? ?? '').trim();
    final provider = providerAlias.isEmpty
        ? null
        : AgentProvider.tryFromAlias(providerAlias);
    if (providerAlias.isNotEmpty && provider == null) {
      warnings.add('proveedor inválido $providerAlias para @$handle');
      continue;
    }
    final model = (data['model'] as String? ?? '').trim();
    final effort = (data['effort'] as String? ?? '').trim();
    projects.setMemberTuning(
      project.id,
      profile.id,
      provider: provider,
      model: model.isEmpty ? null : model,
      effort: effort.isEmpty ? null : effort,
    );
  }

  for (final raw in (arguments['node_assignments'] as List?) ?? const []) {
    if (raw is! Map) continue;
    final data = raw.cast<String, Object?>();
    final workflowName = (data['workflow'] as String? ?? '').trim();
    final nodeId = (data['node_id'] as String? ?? '').trim();
    final handle = (data['handle'] as String? ?? '').trim();
    final workflow = workflows
        .where(
          (entry) =>
              entry.name == workflowName && workflowIds.contains(entry.id),
        )
        .firstOrNull;
    // Un handle vacío BORRA, y un borrado no necesita que el nodo exista:
    // se borra JUSTAMENTE porque ya no existe. Exigirlo también acá dejaba
    // la fila huérfana sin forma de limpiarse. El workflow sí sigue
    // haciendo falta: es la clave del mapa de asignaciones.
    final isRemoval = handle.isEmpty;
    if (workflow == null ||
        (!isRemoval &&
            !workflow.capabilities.any((entry) => entry.id == nodeId))) {
      warnings.add('asignación inválida $workflowName/$nodeId');
      continue;
    }
    final profile = handle.isEmpty
        ? null
        : profiles
              .where(
                (entry) =>
                    entry.name == handle && profileIds.contains(entry.id),
              )
              .firstOrNull;
    if (handle.isNotEmpty && profile == null) {
      warnings.add('no pude asignar @$handle a $workflowName/$nodeId');
      continue;
    }
    if (!projects.setWorkflowNodeAssignment(
      project.id,
      workflow.id,
      nodeId,
      profile?.id,
    )) {
      warnings.add('$workflowName/$nodeId ya está corriendo o cerrado');
    }
  }

  final suffix = warnings.isEmpty ? '' : ' (${warnings.join('; ')})';
  return (true, 'Actualicé el proyecto "${project.name}"$suffix.');
}

(bool, String) _openProjectSession({
  required String project,
  required String prompt,
}) {
  final projects = ProjectsService.instance.notifier;
  final target = projects.data.projects
      .where((entry) => entry.name == project)
      .firstOrNull;
  if (target == null) return (false, 'No existe el proyecto "$project".');
  if (target.profileIds.isEmpty) {
    return (
      false,
      'El proyecto "$project" no tiene miembros: nadie puede tomar la sesión.',
    );
  }
  if (prompt.isEmpty) return (false, 'La sesión necesita un prompt.');

  projects.createSession(target.id);
  final session = projects.data.projects
      .firstWhere((entry) => entry.id == target.id)
      .activeSession;
  if (session == null) return (false, 'No se pudo crear la sesión.');

  unawaited(projects.sendToChannel(target.id, prompt));
  return (
    true,
    'Abrí una sesión en "${target.name}" y le pasé el pedido. Sus miembros '
        'ya están trabajando.',
  );
}

// ───────── Leer sesiones y contestar adentro de una ─────────
//
// Las tres primeras leen; `reply_in_session` escribe, y escribe por la MISMA
// puerta que el compositor del canal (`ProjectsViewModel.replyInSession` →
// `_sendToSession`), no por plomería aparte: si la sesión está corriendo, el
// mensaje se encola y sale como el turno siguiente, que es el caso normal.

/// Cuánto texto de un mensaje entra en un listado. El hilo entero de una
/// sesión larga no cabe en un turno, y para decidir cuál mirar alcanza con
/// el principio.
const _threadPreviewLimit = 400;

/// Cuánto texto entra al resolver una referencia. Acá sí interesa el mensaje
/// completo, pero un turno con veinte ediciones de archivo tampoco sirve.
const _resolvedMessageLimit = 4000;

/// Cuántos mensajes de cada lado acompañan al resuelto. El punto de la tool
/// es poder EXPLICAR a qué se refiere, y para eso hace falta lo que se dijo
/// alrededor, no solo la línea señalada.
const _referenceNeighbours = 3;

(bool, String) _listProjectSessions(String projectName) {
  final project = _projectNamed(projectName);
  if (project == null) return (false, 'No existe el proyecto "$projectName".');
  if (project.sessions.isEmpty) {
    return (true, 'El proyecto "${project.name}" todavía no tiene sesiones.');
  }

  final lines = <String>[];
  for (final session in project.sessions) {
    final active = session.id == project.activeSessionId ? ' · ACTIVA' : '';
    final running = session.isRunning ? ' · corriendo' : '';
    lines.add(
      '- ${session.title} (id: ${session.id})$active$running\n'
      '  estado: ${session.status.name} · abierta: '
      '${session.createdAt.toIso8601String()} · '
      'mensajes: ${session.messages.length}',
    );
  }
  return (
    true,
    'Sesiones de "${project.name}":\n${lines.join('\n')}\n\n'
        'Para leer una: read_session_thread(project, session).',
  );
}

(bool, String) _readSessionThread({
  required String project,
  required String session,
  required int limit,
}) {
  final target = _projectNamed(project);
  if (target == null) return (false, 'No existe el proyecto "$project".');

  final open = _sessionOf(target, session);
  if (open == null) {
    return (
      false,
      session.isEmpty
          ? 'El proyecto "${target.name}" no tiene una sesión activa.'
          : 'No encontré la sesión "$session" en "${target.name}".',
    );
  }
  if (open.messages.isEmpty) {
    return (true, 'La sesión "${open.title}" todavía no tiene mensajes.');
  }

  final bounded = limit <= 0 ? 40 : limit;
  final from = open.messages.length > bounded
      ? open.messages.length - bounded
      : 0;
  final lines = <String>[];
  for (var index = from; index < open.messages.length; index++) {
    lines.add(
      _threadLine(
        target,
        open,
        open.messages[index],
        textLimit: _threadPreviewLimit,
      ),
    );
  }

  final omitted = from > 0
      ? 'Se omitieron los $from mensajes anteriores.\n'
      : '';
  return (
    true,
    'Hilo de "${open.title}" en "${target.name}" '
        '(${open.messages.length} mensajes)\n$omitted\n${lines.join('\n\n')}',
  );
}

(bool, String) _resolveMessageReference(String raw) {
  final reference = SessionMessageReference.tryParse(raw);
  if (reference == null) {
    return (
      false,
      'Eso no es una referencia de mensaje. Tiene la forma '
          'keel://message/<id>?project=<id>&session=<id>, y sale del botón de '
          'copiar de una burbuja del hilo.',
    );
  }

  final found = _locateMessage(reference);
  if (found == null) {
    return (
      false,
      'La referencia no resuelve: el proyecto, la sesión o el mensaje ya no '
          'existen. Pedile al usuario que la vuelva a copiar.',
    );
  }

  final (:project, :session, :message, :index) = found;
  final before = <String>[];
  for (
    var i = index - _referenceNeighbours < 0 ? 0 : index - _referenceNeighbours;
    i < index;
    i++
  ) {
    before.add(
      _threadLine(
        project,
        session,
        session.messages[i],
        textLimit: _threadPreviewLimit,
      ),
    );
  }
  final after = <String>[];
  final last = index + _referenceNeighbours >= session.messages.length
      ? session.messages.length - 1
      : index + _referenceNeighbours;
  for (var i = index + 1; i <= last; i++) {
    after.add(
      _threadLine(
        project,
        session,
        session.messages[i],
        textLimit: _threadPreviewLimit,
      ),
    );
  }

  return (
    true,
    'REFERENCIA RESUELTA\n'
        'Proyecto: ${project.name}\n'
        'Sesión: ${session.title} (id: ${session.id})'
        '${session.isRunning ? ' · corriendo ahora' : ''}\n'
        'Pedido original de la sesión: '
        '${_bounded(session.request, _threadPreviewLimit)}\n'
        '\n'
        'EL MENSAJE\n'
        '${_threadLine(project, session, message, textLimit: _resolvedMessageLimit)}\n'
        '\n'
        'ANTES\n${before.isEmpty ? '(es el primero del hilo)' : before.join('\n\n')}\n'
        '\n'
        'DESPUÉS\n${after.isEmpty ? '(es el último del hilo)' : after.join('\n\n')}\n'
        '\n'
        'Explicale al usuario a qué se refiere. Para contestar, esperá a que '
        'te lo pida y usá reply_in_session con esta misma referencia.',
  );
}

(bool, String) _replyInSession({
  required String rawReference,
  required String text,
}) {
  if (text.isEmpty) return (false, 'La respuesta no puede ir vacía.');

  final reference = SessionMessageReference.tryParse(rawReference);
  if (reference == null) {
    return (false, 'Eso no es una referencia de mensaje válida.');
  }
  final found = _locateMessage(reference);
  if (found == null) {
    return (
      false,
      'No pude contestar: la referencia ya no resuelve a un mensaje de una '
          'sesión existente.',
    );
  }

  final (:project, :session, :message, index: _) = found;
  final prompt = assistantReplyRequest(
    authorHandle: _handleOf(message.authorProfileId),
    nodeId: message.workNodeId,
    askedAt: message.timestamp,
    quotedText: message.text,
    answer: text,
  );

  // Sin `await`, igual que `open_project_session` y por la misma razón: si la
  // sesión no está corriendo, esto abre el turno del miembro y ese turno dura
  // lo que dure. Esperarlo dejaría la tool colgada minutos y al usuario sin
  // respuesta en el chat, cuando lo único que tiene que confirmar es que el
  // mensaje salió.
  final wasRunning = session.isRunning;
  unawaited(
    ProjectsService.instance.notifier.replyInSession(
      project.id,
      session.id,
      prompt,
    ),
  );

  return (
    true,
    wasRunning
        ? 'Mandé la respuesta al canal de "${session.title}" en '
              '"${project.name}". La sesión está trabajando, así que entra '
              'como el turno siguiente — no la repitas.'
        : 'Mandé la respuesta al canal de "${session.title}" en '
              '"${project.name}". El miembro ya la está leyendo.',
  );
}

Project? _projectNamed(String name) => ProjectsService
    .instance
    .notifier
    .data
    .projects
    .where((entry) => entry.name == name)
    .firstOrNull;

/// La sesión pedida por id o por título exacto; vacío devuelve la activa.
Session? _sessionOf(Project project, String idOrTitle) {
  if (idOrTitle.isEmpty) return project.activeSession;
  return project.sessions
          .where((entry) => entry.id == idOrTitle)
          .firstOrNull ??
      project.sessions.where((entry) => entry.title == idOrTitle).firstOrNull;
}

({Project project, Session session, ChatMessage message, int index})?
_locateMessage(SessionMessageReference reference) {
  final project = ProjectsService.instance.notifier.data.projects
      .where((entry) => entry.id == reference.projectId)
      .firstOrNull;
  if (project == null) return null;
  final session = project.sessions
      .where((entry) => entry.id == reference.sessionId)
      .firstOrNull;
  if (session == null) return null;
  final index = session.messages.indexWhere(
    (entry) => entry.id == reference.messageId,
  );
  if (index < 0) return null;
  return (
    project: project,
    session: session,
    message: session.messages[index],
    index: index,
  );
}

String _threadLine(
  Project project,
  Session session,
  ChatMessage message, {
  required int textLimit,
}) {
  final author = switch (message.role) {
    ChatRole.user => message.viaKeelAi ? 'vos (vía Keel AI)' : 'vos',
    ChatRole.error => 'error del sistema',
    ChatRole.blocked => 'cierre bloqueado',
    ChatRole.system => 'la app',
    ChatRole.assistant => '@${_handleOf(message.authorProfileId) ?? 'miembro'}',
  };
  final node = message.workNodeId == null ? '' : ' · nodo ${message.workNodeId}';
  final consult = message.consultOfProfileId == null
      ? ''
      : ' · consulta de @${_handleOf(message.consultOfProfileId) ?? 'miembro'}';
  final reference = SessionMessageReference(
    projectId: project.id,
    sessionId: session.id,
    messageId: message.id,
  );
  return '[$author · ${message.timestamp.toIso8601String()}$node$consult]\n'
      'ref: ${reference.token}\n'
      '${_bounded(message.text, textLimit)}';
}

String? _handleOf(String? profileId) {
  if (profileId == null) return null;
  return AgentProfilesService.instance.notifier.data.profiles
      .where((profile) => profile.id == profileId)
      .firstOrNull
      ?.name;
}

String _bounded(String text, int limit) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return '(sin texto)';
  return trimmed.length > limit ? '${trimmed.substring(0, limit)}…' : trimmed;
}

/// Estado operativo: lo que está configurado, lo que falta y lo que está
/// corriendo ahora. Sirve para diagnosticar sin adivinar.
String _describeSystem() {
  final settings = SettingsService.instance.notifier.data;
  final secrets = SecretsService.instance.notifier;
  final servers = McpServersService.instance.notifier.data.servers;
  final agents = AgentsService.instance.notifier.data.agents;
  final projects = ProjectsService.instance.notifier.data.projects;

  final pendingSecrets = [
    for (final secret in secrets.data.secrets)
      if (secret.isPending) secret.name,
  ];

  final blockedServers = [
    for (final server in servers)
      if (secrets.pendingOf(server.secretNames).isNotEmpty ||
          secrets.missingOf(server.secretNames).isNotEmpty)
        '${server.name} (falta ${[...secrets.pendingOf(server.secretNames), ...secrets.missingOf(server.secretNames)].join(', ')})',
  ];

  final busyAgents = [
    for (final agent in agents)
      if (agent.isStreaming) agent.name,
  ];

  final runningSessions = [
    for (final project in projects)
      for (final session in project.sessions)
        if (session.isRunning) '${project.name}/${session.title}',
  ];

  final hooks = HooksService.instance.notifier.data.hooks;
  final vault = SystemVaultService.instance.notifier.data;
  final integrityIssues = _catalogInspector().integrityIssues;

  return [
    'Respaldo:',
    '- Vault: ${_orMissing(settings.vaultPath)}',
    '- Repo del vault: ${_orMissing(settings.vaultRepoUrl)}',
    '- Último respaldo: '
        '${vault.lastBackupAt?.toLocal().toString() ?? 'nunca'}',
    '- Pendiente: ${vault.warning ?? 'nada, está subido'}',
    '',
    'Guardarraíles (hooks):',
    '- Activos: '
        '${_orNone([for (final hook in hooks.where((entry) => entry.enabled)) '${hook.name} → ${hook.event.alias}'])}',
    '- Apagados: '
        '${_orNone([for (final hook in hooks.where((entry) => !entry.enabled)) hook.name])}',
    '',
    'Saber:',
    '- Bases: '
        '${_orNone([for (final base in KnowledgeService.instance.notifier.data.bases) base.name])}',
    '',
    'Pendientes:',
    '- Secrets sin valor: ${_orNone(pendingSecrets)}',
    '- MCPs que no van a levantar bien: ${_orNone(blockedServers)}',
    '',
    'Integridad del catálogo:',
    if (integrityIssues.isEmpty)
      '- Sin referencias inválidas detectadas.'
    else
      for (final issue in integrityIssues) '- $issue',
    '',
    'Ahora mismo:',
    '- Agentes respondiendo: ${_orNone(busyAgents)}',
    '- Sesiones corriendo: ${_orNone(runningSessions)}',
    '- Conversaciones abiertas: ${agents.length}',
  ].join('\n');
}

/// Como `_keepKnown` del executor, pero acá: (los que existen, los que no).
(List<String>, List<String>) _keepKnownNames(
  List<String> requested, {
  required Iterable<String> known,
}) {
  final catalog = known.toSet();
  return (
    requested.where(catalog.contains).toList(),
    requested.where((name) => !catalog.contains(name)).toList(),
  );
}

/// First non-empty line, trimmed to fit a listing.
String _firstLine(String text) {
  final line = text
      .split('\n')
      .map((entry) => entry.trim())
      .firstWhere((entry) => entry.isNotEmpty, orElse: () => '');
  if (line.isEmpty) return 'sin descripción';
  return line.length <= 90 ? line : '${line.substring(0, 87)}...';
}

List<String> _stringList(Object? value) =>
    (value as List?)?.cast<String>() ?? const [];

List<WorkflowQualityGate> _workflowQualityGates(Object? value) => [
  for (final name in _stringList(value))
    for (final gate in WorkflowQualityGate.values)
      if (gate.name == name) gate,
];

int? _boundedReplanLimit(Object? value) {
  final number = value as num?;
  return number?.toInt().clamp(0, kMaxReplans).toInt();
}

int? _boundedSubagentLimit(Object? value) {
  final number = value as num?;
  return number?.toInt().clamp(0, kMaxSubagentsPerNode).toInt();
}

int? _boundedReviewCycles(Object? value) {
  final number = value as num?;
  return number?.toInt().clamp(1, kMaxReviewCycles).toInt();
}

/// Los dos topes de tiempo del turno, con los mismos límites que los sliders
/// del formulario. Sin esto la única vía de subirlos era la pantalla, y un
/// workflow cuyo lint bloquea el guardado quedaba sin forma de ajustarlos:
/// el formulario manda siempre las capacidades y el lint corre sobre ellas,
/// mientras que por acá la policy viaja sola.
int? _boundedIdleTimeout(Object? value) {
  final number = value as num?;
  return number?.toInt().clamp(0, 60).toInt();
}

int? _boundedNodeTimeout(Object? value) {
  final number = value as num?;
  return number?.toInt().clamp(0, 240).toInt();
}

List<WorkflowCapability>? _workflowCapabilities(Object? value) {
  if (value == null) return null;
  final capabilities = <WorkflowCapability>[];
  for (final raw in (value as List?) ?? const []) {
    if (raw is! Map) continue;
    final data = raw.cast<String, dynamic>();
    final id = (data['id'] as String? ?? '').trim();
    final title = (data['title'] as String? ?? '').trim();
    final instruction = (data['instruction'] as String? ?? '').trim();
    final role = (data['role'] as String? ?? '').trim();
    if (id.isEmpty || title.isEmpty || instruction.isEmpty || role.isEmpty) {
      continue;
    }
    capabilities.add(
      WorkflowCapability(
        id: id,
        title: title,
        instruction: instruction,
        role: role,
        dependencyIds: _stringList(data['dependencies']),
        activation: data['activation'] == 'optional'
            ? WorkflowCapabilityActivation.optional
            : WorkflowCapabilityActivation.required,
        requiresIndependentOwner: data['independent'] as bool? ?? false,
        executor: WorkflowExecutor.values.firstWhere(
          (entry) => entry.name == data['executor'],
          orElse: () => WorkflowExecutor.newSession,
        ),
        parentCapabilityId: (data['parent_capability_id'] as String? ?? '')
            .trim(),
        maxAgenticTurns: ((data['max_agentic_turns'] as num?)?.toInt() ?? 0)
            .clamp(0, kMaxDeclarableTurns)
            .toInt(),
        readOnly: data['read_only'] as bool? ?? false,
        approvalRequired: data['approval_required'] as bool? ?? false,
        outputContract: (data['output_contract'] as String? ?? '').trim(),
      ),
    );
  }
  return capabilities;
}

/// El catálogo en texto, que es como lo lee un modelo.
///
/// Lleva el id adelante porque es lo que pide `install_mcp_integration`, y
/// la documentación al final porque es a donde hay que ir cuando la ficha
/// quedó vieja.
String _describeMcpCatalog() {
  final buffer = StringBuffer(
    'Integraciones MCP que Keel conoce. Instalá con '
    'install_mcp_integration(catalog_id).\n',
  );
  for (final category in McpCatalogCategory.values) {
    final entries = kMcpCatalog.where((e) => e.category == category);
    if (entries.isEmpty) continue;
    buffer.writeln('\n## ${category.label}');
    for (final entry in entries) {
      final credenciales = entry.credentials.isEmpty
          ? 'sin credencial'
          : entry.credentials.map((c) => c.name).join(', ');
      buffer.writeln(
        '- ${entry.id} — ${entry.name}: ${entry.tagline}. '
        '${entry.transport.alias} · ${entry.detail} · $credenciales. '
        '${entry.docsUrl}',
      );
      if (entry.note.isNotEmpty) buffer.writeln('  Ojo: ${entry.note}');
    }
  }
  return buffer.toString();
}


// ── supervisión de sesiones (solo a pedido del usuario) ─────────────────

String _profileHandle(String profileId) {
  final profile = AgentProfilesService.instance.notifier.data.profiles
      .where((entry) => entry.id == profileId)
      .firstOrNull;
  return profile?.name ?? (profileId.isEmpty ? 'sin dueño' : profileId);
}

(bool, String) _inspectSession({
  required String project,
  required String session,
  required bool full,
}) {
  final target = _projectNamed(project);
  if (target == null) return (false, 'No existe el proyecto "$project".');
  final open = _sessionOf(target, session);
  if (open == null) {
    return (false, 'No encontré esa sesión en "${target.name}".');
  }
  final projects = ProjectsService.instance.notifier;
  final workflow = projects.workflowOf(open);
  final resolution = open.resolutionCase;
  final buffer = StringBuffer()
    ..writeln('SESIÓN "${open.title}" (id: ${open.id}) en "${target.name}"')
    ..writeln(
      'estado: ${open.status.name}'
      '${open.isRunning ? ' · corriendo' : ''}'
      '${open.waitingForUser ? ' · ESPERANDO AL USUARIO' : ''}'
      ' · workflow: ${workflow?.name ?? 'ninguno'}'
      ' · costo reportado: US\$ ${open.usage.reportedCostUsd.toStringAsFixed(2)}'
      ' · turnos: ${open.usage.turns}',
    )
    ..writeln('pedido: ${open.request.isEmpty ? '(vacío)' : open.request}');

  if (resolution != null) {
    buffer
      ..writeln()
      ..writeln(
        'CASO: ${resolution.status.name} · replans ${resolution.replanCount} '
        '· ciclos de auditoría ${resolution.reviewCycleCount}',
      )
      ..writeln('NODOS:');
    for (final node in resolution.nodes) {
      final cost = open.usage.byWorkNodeId[node.id];
      final output = node.output;
      final verdict = switch (output?.verdict) {
        TurnVerdict.go => ' · GO',
        TurnVerdict.noGo => ' · NO-GO',
        null => '',
      };
      buffer.writeln(
        '- ${node.id} · ${node.title.isEmpty ? node.id : node.title} · '
        '${node.status.name} · dueño @${_profileHandle(node.ownerProfileId)} · '
        'intentos ${node.attempts} · US\$ '
        '${(cost?.reportedCostUsd ?? 0).toStringAsFixed(2)}'
        '${output == null ? '' : '\n  cierre: ${output.status.name}$verdict · ${_clipText(output.summary, 400)}'}',
      );
    }
    final digest = sessionDigest(resolution);
    if (digest.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('RESUMEN DEL CASO:')
        ..writeln(digest);
    }
    final findings = resolution.findings
        .where((finding) => finding.status.name != 'resolved')
        .toList();
    if (findings.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('HALLAZGOS ABIERTOS:');
      for (final finding in findings) {
        buffer.writeln(
          '- [${finding.status.name}] ${finding.evidence.source.name} sobre '
          '${finding.affectedNodeId}: ${_clipText(finding.evidence.summary, 300)}',
        );
      }
    }
  }

  final pending = open.pendingDecisions;
  if (pending.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('DECISIONES PENDIENTES (contestables con answer_decision):');
    for (final decision in pending) {
      buffer.writeln(
        '- id ${decision.id} · ${decision.kind.name} · '
        '@${_profileHandle(decision.profileId)} · ${decision.title}'
        '${decision.detail.isEmpty ? '' : ': ${_clipText(decision.detail, 300)}'}'
        '${decision.options.isEmpty ? '' : ' · opciones: ${decision.options.join(' | ')}'}'
        '${decision.blocking ? ' · turno vivo esperando' : ''}',
      );
    }
  }

  if (full) {
    final messages = open.messages.length <= 20
        ? open.messages
        : open.messages.sublist(open.messages.length - 20);
    buffer
      ..writeln()
      ..writeln('ÚLTIMOS ${messages.length} MENSAJES:');
    for (final message in messages) {
      final author = message.role == ChatRole.assistant
          ? '@${_profileHandle(message.authorProfileId ?? '')}'
          : message.role.name;
      buffer.writeln(
        '[${message.timestamp.toIso8601String()}] $author'
        '${message.workNodeId == null ? '' : ' · nodo ${message.workNodeId}'}: '
        '${message.text}',
      );
    }
    if (open.subagents.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('SUBAGENTES:');
      for (final subagent in open.subagents) {
        buffer.writeln(
          '- ${subagent.phase.name} · ${_clipText(subagent.ask, 200)}'
          '${subagent.result.isEmpty ? '' : '\n  resultado: ${_clipText(subagent.result, 600)}'}',
        );
      }
    }
  }
  return (true, buffer.toString().trimRight());
}

(bool, String) _intervene({
  required String project,
  required String session,
  required String text,
}) {
  if (text.isEmpty) return (false, 'La instrucción no puede ir vacía.');
  final target = _projectNamed(project);
  if (target == null) return (false, 'No existe el proyecto "$project".');
  final open = _sessionOf(target, session);
  if (open == null) {
    return (false, 'No encontré esa sesión en "${target.name}".');
  }
  final projects = ProjectsService.instance.notifier;
  if (open.isRunning) {
    // Sin await: interrumpir dispara el turno siguiente, que dura lo que
    // dure. Lo único que hay que confirmar es que el mensaje entró.
    unawaited(() async {
      final id = await projects.queueSessionMessage(
        target.id,
        open.id,
        text,
        viaKeelAi: true,
      );
      if (id != null) {
        await projects.sendQueuedSessionMessageNow(target.id, open.id, id);
      }
    }());
    return (
      true,
      'Interrumpí "${open.title}" en "${target.name}" con tu instrucción; '
          'el nodo en curso vuelve a pendiente y el workflow lo retoma después '
          'de atenderla.',
    );
  }
  unawaited(projects.replyInSession(target.id, open.id, text));
  return (
    true,
    'Mandé la instrucción al canal de "${open.title}" en "${target.name}"; '
        'abre el turno siguiente.',
  );
}

Future<(bool, String)> _answerDecision({
  required String project,
  required String session,
  required String decisionId,
  required String answer,
  required bool? approve,
  required String scope,
}) async {
  final target = _projectNamed(project);
  if (target == null) return (false, 'No existe el proyecto "$project".');
  final open = _sessionOf(target, session);
  if (open == null) {
    return (false, 'No encontré esa sesión en "${target.name}".');
  }
  final decision = open.decisions
      .where((entry) => entry.id == decisionId && entry.isPending)
      .firstOrNull;
  if (decision == null) {
    return (false, 'No hay una decisión pendiente con id $decisionId.');
  }
  final error = await ProjectsService.instance.notifier.answerSessionDecision(
    target.id,
    open.id,
    decisionId,
    answer: answer,
    approve: approve,
    scope: scope,
  );
  if (error != null) return (false, error);
  return (
    true,
    'Contesté la decisión "${decision.title}" de '
        '@${_profileHandle(decision.profileId)}'
        '${decision.blocking ? '; el turno sigue.' : '; el nodo retoma.'}',
  );
}

(bool, String) _lintWorkflow(Object? rawCapabilities) {
  final capabilities = _workflowCapabilities(rawCapabilities) ?? const [];
  if (capabilities.isEmpty) {
    return (false, 'No hay capacidades válidas que revisar.');
  }
  final structural = validateWorkflowCapabilities(capabilities);
  final lints = lintWorkflowCapabilities(capabilities);
  if (structural == null && lints.isEmpty) {
    return (true, 'Sin observaciones: ${capabilities.length} nodos.');
  }
  final lines = [
    if (structural != null) 'error: $structural',
    for (final lint in lints) lint.toString(),
  ];
  final hasErrors =
      structural != null ||
      lints.any((lint) => lint.severity == WorkflowLintSeverity.error);
  return (
    true,
    '${hasErrors ? 'HAY ERRORES (create_workflow los rechazaría):' : 'Solo avisos:'}\n'
        '${lines.join('\n')}',
  );
}

String _clipText(String text, int max) {
  final trimmed = text.trim();
  return trimmed.length <= max ? trimmed : '${trimmed.substring(0, max)}…';
}
