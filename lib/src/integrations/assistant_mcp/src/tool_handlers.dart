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

  if (request.name == 'backup_system' || request.name == 'restore_system') {
    final vault = SystemVaultService.instance.notifier;
    final message = await _runVaultTool(vault, request);
    AgentsService.instance.notifier.appendSystemNote(agentId, message);
    return CallToolResult(
      content: [
        TextContent(text: jsonEncode({'ok': true, 'message': message})),
      ],
    );
  }

  final (ok, message) = _runKeelAiTool(agentId, request);
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
  'list_secret_names',
  'get_item',
  'describe_system',
};

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

    case 'get_item':
      return _getItem(
        (arguments['kind'] as String).trim().toLowerCase(),
        (arguments['name'] as String).trim(),
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
      final steps = arguments['steps'] == null
          ? workflow.steps
          : _parseToolSteps(arguments['steps']);
      if (steps.isEmpty) {
        return (false, 'Un workflow sin pasos no sirve: mandá al menos uno.');
      }
      final error = workflows.updateWorkflow(
        workflow.id,
        name: (arguments['new_name'] as String?)?.trim().isNotEmpty ?? false
            ? (arguments['new_name'] as String).trim()
            : workflow.name,
        whenToApply:
            arguments['when_to_apply'] as String? ?? workflow.whenToApply,
        steps: steps,
      );
      return (
        error == null,
        error ??
            'Actualicé el workflow "${workflow.name}" '
                '(${steps.length} pasos).',
      );

    case 'unassign_from_agent':
      return _unassignFromAgent(
        handle: (arguments['handle'] as String).trim(),
        skills: _stringList(arguments['skill_names']),
        rules: _stringList(arguments['rule_names']),
        tools: _stringList(arguments['tool_names']),
        mcpServers: _stringList(arguments['mcp_server_names']),
      );

    case 'update_project':
      return _updateProject(arguments);

    case 'open_project_session':
      return _openProjectSession(
        project: (arguments['project'] as String).trim(),
        prompt: (arguments['prompt'] as String).trim(),
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
          knowledgeBaseNames: _stringList(arguments['knowledge_base_names']),
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

    case 'create_project':
      final result = executeProjectAction(
        CreateProjectAction(
          name: arguments['name'] as String,
          purpose: arguments['purpose'] as String? ?? '',
          workingDirectory: arguments['working_directory'] as String? ?? '',
          agentHandles: _stringList(arguments['agent_handles']),
          workflowNames: _stringList(arguments['workflow_names']),
          ruleNames: _stringList(arguments['rule_names']),
          knowledgeBaseNames: _stringList(arguments['knowledge_base_names']),
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
        delete: WorkflowsService.instance.notifier.deleteWorkflow,
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
      '- ${workflow.name} (${workflow.steps.length} pasos) — '
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
          '${_mcpTarget(server)}',
  ]);

  final knowledge = KnowledgeService.instance.notifier;
  section('knowledge_bases', 'Bases de saber', [
    for (final base in knowledge.data.bases)
      '- ${base.name} (${knowledge.indexOf(base.id)?.documentCount ?? 0} '
          'documentos) — ${_firstLine(base.description)}',
  ]);

  if (sections.isEmpty) {
    return 'No conozco el tipo "$kind". Válidos: skills, rules, tools, '
        'agents, workflows, projects, mcp_servers, knowledge_bases, all.';
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
      return (
        true,
        'Agente @${profile.name}\n'
            'Rol: ${profile.role}\n'
            'Proveedor: ${profile.provider.alias} | modelo: ${profile.model} '
            '| esfuerzo: ${profile.effort}\n'
            'Constructor del sistema: ${profile.canManageSystem ? 'sí' : 'no'}\n'
            'Skills: ${_orNone(profile.skills)}\n'
            'Reglas: ${_orNone(profile.rules)}\n'
            'Tools: ${_orNone(profile.tools)}\n'
            'MCPs: ${_orNone(profile.mcpServers)}\n\n'
            'System prompt:\n${profile.systemPrompt}',
      );

    case 'workflow':
      final workflow = WorkflowsService.instance.notifier.data.workflows
          .where((entry) => entry.name == name)
          .firstOrNull;
      if (workflow == null) return (false, 'No existe el workflow "$name".');
      final steps = [
        for (final (index, step) in workflow.steps.indexed)
          '${index + 1}. ${step.title} [${step.role}]\n   ${step.instruction}',
      ];
      return (
        true,
        'Workflow "${workflow.name}"\n'
            'Cuándo aplica: ${workflow.whenToApply}\n\n'
            '${steps.isEmpty ? '(sin pasos)' : steps.join('\n')}',
      );

    case 'project':
      final project = ProjectsService.instance.notifier.data.projects
          .where((entry) => entry.name == name)
          .firstOrNull;
      if (project == null) return (false, 'No existe el proyecto "$name".');
      final profiles = AgentProfilesService.instance.notifier.data.profiles;
      final workflows = WorkflowsService.instance.notifier.data.workflows;
      final members = [
        for (final id in project.profileIds)
          '@${profiles.where((p) => p.id == id).firstOrNull?.name ?? id}',
      ];
      final available = [
        for (final id in project.workflowIds)
          workflows.where((w) => w.id == id).firstOrNull?.name ?? id,
      ];
      final active = project.activeWorkflowId == null
          ? 'ninguno'
          : workflows
                    .where((w) => w.id == project.activeWorkflowId)
                    .firstOrNull
                    ?.name ??
                project.activeWorkflowId!;
      return (
        true,
        'Proyecto "${project.name}"\n'
            'Propósito: ${project.purpose}\n'
            'Directorio: ${project.workingDirectory}\n'
            'Miembros: ${_orNone(members)}\n'
            'Workflows disponibles: ${_orNone(available)}\n'
            'Workflow activo: $active\n'
            'Reglas: ${_orNone(project.ruleNames)}\n'
            'Saber: ${_orNone(project.knowledgeBaseNames)}\n'
            'Sesiones: ${project.sessions.length}\n'
            'Lo mantiene el usuario: ${project.maintained ? 'sí' : 'NO — solo lectura'}',
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

    case 'mcp_server':
      final server = McpServersService.instance.notifier.data.servers
          .where((entry) => entry.name == name)
          .firstOrNull;
      if (server == null) return (false, 'No existe el MCP "$name".');
      return (
        true,
        'MCP "${server.name}" (${server.transport.alias})\n'
            'Destino: ${_mcpTarget(server)}\n'
            'Env literales: ${server.env.isEmpty ? 'ninguna' : server.env.keys.join(', ')}\n'
            'Secrets: ${_orNone(server.secretNames)}',
      );

    default:
      return (
        false,
        'No conozco el tipo "$kind". Válidos: skill, rule, tool, agent, '
            'workflow, project, mcp_server.',
      );
  }
}

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
  if (request.name == 'backup_system') {
    final push = request.arguments?['push'] as bool? ?? false;
    return vault.backup(reach: push ? VaultReach.push : VaultReach.write);
  }
  final read = await vault.inspectVault();
  if (vault.data.preview == null) return read;
  return vault.applyLoaded(sections: BackupSection.values.toSet());
}

String _mcpTarget(McpServerConfig server) {
  return switch (server.transport) {
    McpTransport.stdio => '${server.command} ${server.args.join(' ')}'.trim(),
    McpTransport.http || McpTransport.sse => server.url,
  };
}

/// Saca asignaciones de un agente. `create_or_update_agent` solo suma, así
/// que sin esto la única forma de corregir una asignación equivocada era
/// borrar el agente y rehacerlo — perdiendo su historial de conversación.
(bool, String) _unassignFromAgent({
  required String handle,
  required List<String> skills,
  required List<String> rules,
  required List<String> tools,
  required List<String> mcpServers,
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

  if (skills.isEmpty && rules.isEmpty && tools.isEmpty && mcpServers.isEmpty) {
    return (false, 'No me dijiste qué sacarle a "@$cleanHandle".');
  }

  final error = viewmodel.updateProfile(
    profile.id,
    name: profile.name,
    role: profile.role,
    systemPrompt: profile.systemPrompt,
    skills: _without(profile.skills, skills),
    rules: _without(profile.rules, rules),
    tools: _without(profile.tools, tools),
    mcpServers: _without(profile.mcpServers, mcpServers),
    model: profile.model,
    effort: profile.effort,
  );
  if (error != null) return (false, error);

  final removed = [
    if (skills.isNotEmpty) 'skills: ${skills.join(', ')}',
    if (rules.isNotEmpty) 'reglas: ${rules.join(', ')}',
    if (tools.isNotEmpty) 'tools: ${tools.join(', ')}',
    if (mcpServers.isNotEmpty) 'MCPs: ${mcpServers.join(', ')}',
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
    // Reenviados a propósito: `updateProject` reemplaza la lista entera, así
    // que omitirlos acá borraba los guardarraíles del proyecto en cada
    // update que no los mencionara — y la marca de mantenedor haría lo mismo.
    hookNames: project.hookNames,
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
