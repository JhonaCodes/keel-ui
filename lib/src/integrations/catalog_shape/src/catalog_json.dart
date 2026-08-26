part of '../catalog_shape.dart';

/// Las categorías del catálogo portable, en el orden en que se escriben.
const kCatalogCategories = [
  'skills',
  'rules',
  'hooks',
  'tools',
  'workflows',
  'mcp_servers',
  'knowledge_bases',
  'profiles',
  'projects',
  'requirements',
  'boards',
  'catalog_locks',
];

/// El nombre de archivo de una entidad dentro de su categoría. Los
/// separadores de ruta se neutralizan: un nombre no puede abrir una carpeta.
String catalogFileNameFor(String name) =>
    '${name.replaceAll(RegExp(r'[/\\:]'), '_')}.json';

/// El catálogo vivo serializado POR NOMBRE, categoría → entidades. Única
/// fuente de la forma portable: el vault la mete en un zip y el respaldo en
/// un solo JSON — dos destinos, una forma.
Map<String, List<Map<String, dynamic>>> catalogAsJson() {
  final byCategory = {
    for (final category in kCatalogCategories)
      category: <Map<String, dynamic>>[],
  };

  for (final lock in CatalogLocksService.instance.notifier.data.locks) {
    byCategory['catalog_locks']!.add({
      'name': lock.key,
      'kind': lock.kind.alias,
      'itemName': lock.name,
      'createdAt': lock.createdAt.toIso8601String(),
    });
  }

  for (final skill in SkillsService.instance.notifier.data.skills) {
    // The system map is compiled app knowledge, re-seeded on every launch —
    // exporting it would just ship a stale copy.
    if (skill.name == kKeelAiSkillNameForExport) continue;
    byCategory['skills']!.add({
      'name': skill.name,
      'content': skill.content,
      'isGlobal': skill.isGlobal,
    });
  }

  for (final rule in RulesService.instance.notifier.data.rules) {
    byCategory['rules']!.add({'name': rule.name, 'content': rule.content});
  }

  for (final hook in HooksService.instance.notifier.data.hooks) {
    byCategory['hooks']!.add({
      'name': hook.name,
      'description': hook.description,
      'event': hook.event.alias,
      'matcher': hook.matcher,
      'body': hook.body.toJson(),
      'timeoutSeconds': hook.timeoutSeconds,
      'enforces': hook.enforces,
      'isGlobal': hook.isGlobal,
      'enabled': hook.enabled,
    });
  }

  for (final tool in ToolsService.instance.notifier.data.tools) {
    byCategory['tools']!.add({
      'name': tool.name,
      'description': tool.description,
      'runtime': tool.runtime.alias,
      'code': tool.code,
      'timeoutSeconds': tool.timeoutSeconds,
      'secretNames': tool.secretNames,
    });
  }

  for (final workflow in WorkflowsService.instance.notifier.data.workflows) {
    byCategory['workflows']!.add({
      'name': workflow.name,
      'whenToApply': workflow.whenToApply,
      'skillNames': workflow.skillNames,
      'buildsRoadmap': workflow.buildsRoadmap,
      'kind': workflow.kind.name,
      'policy': workflow.policy.toJson(),
    });
  }

  for (final server in McpServersService.instance.notifier.data.servers) {
    byCategory['mcp_servers']!.add({
      'name': server.name,
      'transport': server.transport.alias,
      'command': server.command,
      'args': server.args,
      'env': server.env,
      // Names only — values live in the local secrets vault, never here.
      'secretEnv': server.secretEnv,
      'url': server.url,
      'headers': server.headers,
    });
  }

  for (final base in KnowledgeService.instance.notifier.data.bases) {
    final relative = base.source == KnowledgeSource.local
        ? vaultRelativeOf(base.localPath)
        : null;
    byCategory['knowledge_bases']!.add({
      'name': base.name,
      'description': base.description,
      'source': base.source.alias,
      'gitUrl': base.gitUrl,
      'gitBranch': base.gitBranch,
      // La ruta ABSOLUTA no viaja, igual que el directorio de un proyecto.
      // La relativa al vault sí: del otro lado el vault existe y la base se
      // reengancha sola. Una base fuera del vault sigue llegando sin
      // carpeta y la UI la pide.
      'vaultPath': ?relative,
    });
  }

  final profiles = AgentProfilesService.instance.notifier.data.profiles;
  for (final profile in profiles) {
    if (profile.name == kKeelAiHandle) continue;
    byCategory['profiles']!.add({
      'name': profile.name,
      'role': profile.role,
      'systemPrompt': profile.systemPrompt,
      'skills': profile.skills,
      'rules': profile.rules,
      'hooks': profile.hooks,
      'tools': profile.tools,
      'mcpServers': profile.mcpServers,
      'knowledgeBaseNames': profile.knowledgeBaseNames,
      'canManageSystem': profile.canManageSystem,
      'provider': profile.provider.alias,
      'model': profile.model,
      'effort': profile.effort,
    });
  }

  final projectsViewModel = ProjectsService.instance.notifier;
  for (final project in projectsViewModel.data.projects) {
    final workflows = WorkflowsService.instance.notifier.data.workflows;
    String? workflowNameOf(String id) =>
        workflows.where((workflow) => workflow.id == id).firstOrNull?.name;
    byCategory['projects']!.add({
      'name': project.name,
      'purpose': project.purpose,
      // Portable references only: handles and names. Working directory and
      // sessions are machine-local and NEVER exported.
      'agentHandles': [
        for (final id in project.profileIds)
          profiles.where((profile) => profile.id == id).firstOrNull?.name,
      ].whereType<String>().toList(),
      'workflowNames': project.workflowIds
          .map(workflowNameOf)
          .whereType<String>()
          .toList(),
      'ruleNames': project.ruleNames,
      'hookNames': project.hookNames,
      'knowledgeBaseNames': project.knowledgeBaseNames,
      // Quién mantiene el repo no es de esta máquina: viaja.
      'maintained': project.maintained,
      // Con qué motor corre cada miembro acá, por handle: es configuración
      // del proyecto, así que viaja con él o se pierde en el import.
      'memberEngines': _engineMirror(project, profiles),
      'activeWorkflowName': project.activeWorkflowId == null
          ? null
          : workflowNameOf(project.activeWorkflowId!),
    });
  }

  // Los requerimientos viajan porque son una DECISIÓN entre dos proyectos,
  // no ruido de una sesión: qué se pidió, qué contestó el otro lado y qué
  // dijiste vos en el medio. Los ids y las sesiones son de esta máquina y no
  // salen; los proyectos viajan por nombre, como todo lo demás.
  for (final requirement
      in RequirementsService.instance.notifier.data.requirements) {
    String? nameOf(String id) => projectsViewModel.data.projects
        .where((project) => project.id == id)
        .firstOrNull
        ?.name;
    final from = nameOf(requirement.fromProjectId);
    final to = nameOf(requirement.toProjectId);
    if (from == null || to == null) continue;

    byCategory['requirements']!.add({
      'name': requirement.code,
      'title': requirement.title,
      'fromProject': from,
      'toProject': to,
      'need': requirement.need,
      'context': requirement.context,
      'blocking': requirement.blocking,
      'openedByHandle': requirement.openedByHandle,
      'takenByHandle': requirement.takenByHandle,
      'status': requirement.status.alias,
      'verdict': requirement.verdict?.toJson(),
      'thread': requirement.thread.map((entry) => entry.toJson()).toList(),
      'createdAt': requirement.createdAt.toIso8601String(),
      'updatedAt': requirement.updatedAt.toIso8601String(),
    });
  }

  // Los tableros viajan porque son DEFINICIÓN: qué campos tiene, qué
  // dispara, contra qué endpoint. Lo que no viaja son sus corridas —lo que
  // te contestó tu API de desarrollo el martes no le sirve a nadie— ni el
  // valor de los secrets que usan, que se referencian por nombre.
  for (final board in BoardsService.instance.notifier.data.boards) {
    final project = projectsViewModel.data.projects
        .where((candidate) => candidate.id == board.projectId)
        .firstOrNull;
    if (project == null) continue;

    byCategory['boards']!.add({
      // El nombre es único DENTRO del proyecto, así que la clave portable
      // los lleva a los dos: dos proyectos pueden tener su "Lanzar oferta".
      'name': '${project.name} · ${board.name}',
      'board': board.name,
      'project': project.name,
      'note': board.note,
      'fields': [for (final field in board.fields) field.toJson()],
      'actions': [for (final action in board.actions) action.toJson()],
      'createdAt': board.createdAt.toIso8601String(),
      'updatedAt': board.updatedAt.toIso8601String(),
    });
  }

  return byCategory;
}

/// Los ajustes de motor de [project] rekeyados por handle. Un ajuste de un
/// perfil que ya no existe no se escribe: la forma es portable y un id
/// suelto no significa nada del otro lado.
Map<String, dynamic> _engineMirror(
  Project project,
  List<AgentProfile> profiles,
) {
  final mirror = <String, dynamic>{};
  for (final entry in project.memberTuning.entries) {
    final handle = profiles
        .where((profile) => profile.id == entry.key)
        .firstOrNull
        ?.name;
    if (handle == null) continue;
    mirror[handle] = entry.value.toJson();
  }
  return mirror;
}

/// Los ajustes de motor de un archivo de proyecto, por handle. Un archivo
/// escrito antes de que esto existiera simplemente no trae la clave.
List<MapEntry<String, MemberTuning>> _readEngines(Object? value) {
  if (value is! Map) return const [];
  final engines = <MapEntry<String, MemberTuning>>[];
  for (final entry in value.entries) {
    final config = entry.value;
    if (config is! Map) continue;
    engines.add(
      MapEntry(
        entry.key as String,
        MemberTuning.fromJson(config.cast<String, dynamic>()),
      ),
    );
  }
  return engines;
}

/// La carpeta que le toca a una base local del archivo en ESTA máquina.
///
/// Si el archivo trae una ruta relativa al vault y acá hay vault, la base se
/// reengancha sola (y la carpeta se crea si el repo llegó sin ella). Si no,
/// se respeta la que ya tenga acá: una ruta absoluta ajena nunca se inventa.
String _resolveLocalPath(Map<String, dynamic> json, KnowledgeBase? existing) {
  final relative = json['vaultPath'] as String?;
  final absolute = relative == null ? null : vaultAbsoluteOf(relative);
  if (absolute == null) return existing?.localPath ?? '';

  Directory(absolute).createSync(recursive: true);
  return absolute;
}

/// El merge por nombre sobre el catálogo vivo, desde la forma portable de
/// [catalogAsJson] — venga del zip del vault o de un respaldo en un archivo.
/// Solo toca las categorías presentes en [rawByCategory].
Future<String> mergeCatalogJson(
  Map<String, List<Map<String, dynamic>>> rawByCategory,
) async {
  final byCategory = withLegacyCategoryNames(rawByCategory);
  var created = 0;
  var updated = 0;
  final problems = <String>[];

  void track(String? error, {required bool existed, required String label}) {
    if (error != null) {
      problems.add('$label: $error');
    } else if (existed) {
      updated++;
    } else {
      created++;
    }
  }

  final skills = SkillsService.instance.notifier;
  for (final json in byCategory['skills'] ?? const <Map<String, dynamic>>[]) {
    final name = json['name'] as String;
    if (name == kKeelAiSkillNameForExport) continue;
    final existing = skills.data.skills
        .where((skill) => skill.name == name)
        .firstOrNull;
    final error = existing == null
        ? skills.createSkill(
            name: name,
            content: json['content'] as String? ?? '',
            isGlobal: json['isGlobal'] as bool? ?? false,
          )
        : skills.updateSkill(
            existing.id,
            name: name,
            content: json['content'] as String? ?? '',
            isGlobal: json['isGlobal'] as bool? ?? false,
          );
    track(error, existed: existing != null, label: 'skill $name');
  }

  final rules = RulesService.instance.notifier;
  for (final json in byCategory['rules'] ?? const <Map<String, dynamic>>[]) {
    final name = json['name'] as String;
    final existing = rules.data.rules
        .where((rule) => rule.name == name)
        .firstOrNull;
    final error = existing == null
        ? rules.createRule(
            name: name,
            content: json['content'] as String? ?? '',
          )
        : rules.updateRule(
            existing.id,
            name: name,
            content: json['content'] as String? ?? '',
          );
    track(error, existed: existing != null, label: 'regla $name');
  }

  final hooks = HooksService.instance.notifier;
  for (final json in byCategory['hooks'] ?? const <Map<String, dynamic>>[]) {
    final name = json['name'] as String;
    final event = HookEvent.tryFromAlias(json['event'] as String? ?? '');
    if (event == null) {
      problems.add('hook $name: evento inválido');
      continue;
    }
    final existing = hooks.hookByName(name);
    final body = HookBody.fromJson(
      (json['body'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final error = existing == null
        ? hooks.createHook(
            name: name,
            description: json['description'] as String? ?? '',
            event: event,
            body: body,
            matcher: json['matcher'] as String? ?? '',
            timeoutSeconds:
                json['timeoutSeconds'] as int? ?? kDefaultHookTimeoutSeconds,
            enforces: (json['enforces'] as List?)?.cast<String>() ?? const [],
            isGlobal: json['isGlobal'] as bool? ?? false,
            enabled: json['enabled'] as bool? ?? true,
          )
        : hooks.updateHook(
            existing.id,
            name: name,
            description: json['description'] as String? ?? '',
            event: event,
            body: body,
            matcher: json['matcher'] as String? ?? '',
            timeoutSeconds:
                json['timeoutSeconds'] as int? ?? kDefaultHookTimeoutSeconds,
            enforces: (json['enforces'] as List?)?.cast<String>() ?? const [],
            isGlobal: json['isGlobal'] as bool? ?? false,
            enabled: json['enabled'] as bool? ?? true,
          );
    track(error, existed: existing != null, label: 'hook $name');
  }

  final tools = ToolsService.instance.notifier;
  for (final json in byCategory['tools'] ?? const <Map<String, dynamic>>[]) {
    final name = json['name'] as String;
    final runtime = ToolRuntime.tryFromAlias(json['runtime'] as String? ?? '');
    if (runtime == null) {
      problems.add('tool $name: runtime inválido');
      continue;
    }
    final existing = tools.data.tools
        .where((tool) => tool.name == name)
        .firstOrNull;
    final error = existing == null
        ? tools.createTool(
            name: name,
            description: json['description'] as String? ?? '',
            runtime: runtime,
            code: json['code'] as String? ?? '',
            timeoutSeconds:
                json['timeoutSeconds'] as int? ?? kDefaultToolTimeoutSeconds,
            secretNames:
                (json['secretNames'] as List?)?.cast<String>() ?? const [],
          )
        : tools.updateTool(
            existing.id,
            name: name,
            description: json['description'] as String? ?? '',
            runtime: runtime,
            code: json['code'] as String? ?? '',
            timeoutSeconds:
                json['timeoutSeconds'] as int? ?? kDefaultToolTimeoutSeconds,
            secretNames:
                (json['secretNames'] as List?)?.cast<String>() ?? const [],
          );
    track(error, existed: existing != null, label: 'tool $name');
  }

  final workflows = WorkflowsService.instance.notifier;
  for (final json
      in byCategory['workflows'] ?? const <Map<String, dynamic>>[]) {
    final name = json['name'] as String;
    final skillNames =
        (json['skillNames'] as List?)?.cast<String>() ?? const <String>[];
    final kind = WorkflowKind.values.firstWhere(
      (kind) => kind.name == json['kind'],
      orElse: () => WorkflowKind.general,
    );
    final policy = WorkflowPolicy.fromJson(
      (json['policy'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final existing = workflows.data.workflows
        .where((workflow) => workflow.name == name)
        .firstOrNull;
    final error = existing == null
        ? workflows.createWorkflow(
            name: name,
            whenToApply: json['whenToApply'] as String? ?? '',
            kind: kind,
            policy: policy,
            skillNames: skillNames,
            buildsRoadmap: json['buildsRoadmap'] as bool? ?? false,
          )
        : workflows.updateWorkflow(
            existing.id,
            name: name,
            whenToApply: json['whenToApply'] as String? ?? '',
            kind: kind,
            policy: policy,
            skillNames: skillNames,
            buildsRoadmap: json['buildsRoadmap'] as bool? ?? false,
          );
    track(error, existed: existing != null, label: 'workflow $name');
  }

  final servers = McpServersService.instance.notifier;
  for (final json
      in byCategory['mcp_servers'] ?? const <Map<String, dynamic>>[]) {
    final name = json['name'] as String;
    final transport = McpTransport.tryFromAlias(
      json['transport'] as String? ?? '',
    );
    if (transport == null) {
      problems.add('mcp $name: transporte inválido');
      continue;
    }
    final existing = servers.data.servers
        .where((server) => server.name == name)
        .firstOrNull;
    final error = existing == null
        ? servers.createServer(
            name: name,
            transport: transport,
            command: json['command'] as String? ?? '',
            args: (json['args'] as List?)?.cast<String>() ?? const [],
            env: (json['env'] as Map?)?.cast<String, String>() ?? const {},
            secretEnv:
                (json['secretEnv'] as Map?)?.cast<String, String>() ?? const {},
            url: json['url'] as String? ?? '',
            headers:
                (json['headers'] as Map?)?.cast<String, String>() ?? const {},
          )
        : servers.updateServer(
            existing.id,
            name: name,
            transport: transport,
            command: json['command'] as String? ?? '',
            args: (json['args'] as List?)?.cast<String>() ?? const [],
            env: (json['env'] as Map?)?.cast<String, String>() ?? const {},
            secretEnv:
                (json['secretEnv'] as Map?)?.cast<String, String>() ?? const {},
            url: json['url'] as String? ?? '',
            headers:
                (json['headers'] as Map?)?.cast<String, String>() ?? const {},
          );
    track(error, existed: existing != null, label: 'mcp $name');
  }

  final knowledge = KnowledgeService.instance.notifier;
  for (final json
      in byCategory['knowledge_bases'] ?? const <Map<String, dynamic>>[]) {
    final name = json['name'] as String;
    final source = KnowledgeSource.tryFromAlias(
      json['source'] as String? ?? '',
    );
    if (source == null) {
      problems.add('base de saber $name: fuente inválida');
      continue;
    }
    final existing = knowledge.baseByName(name);
    final localPath = _resolveLocalPath(json, existing);
    final error = existing == null
        ? knowledge.createBase(
            name: name,
            description: json['description'] as String? ?? '',
            source: source,
            gitUrl: json['gitUrl'] as String? ?? '',
            gitBranch: json['gitBranch'] as String? ?? '',
            localPath: localPath,
          )
        : knowledge.updateBase(
            existing.id,
            name: name,
            description: json['description'] as String? ?? '',
            source: source,
            gitUrl: json['gitUrl'] as String? ?? '',
            gitBranch: json['gitBranch'] as String? ?? '',
            localPath: localPath,
          );
    track(error, existed: existing != null, label: 'base de saber $name');
  }

  final profiles = AgentProfilesService.instance.notifier;
  for (final json in byCategory['profiles'] ?? const <Map<String, dynamic>>[]) {
    final name = json['name'] as String;
    if (name == kKeelAiHandle) continue;
    final provider =
        AgentProvider.tryFromAlias(json['provider'] as String? ?? 'claude') ??
        AgentProvider.claude;
    final existing = profiles.data.profiles
        .where((profile) => profile.name == name)
        .firstOrNull;
    final error = existing == null
        ? profiles.createProfile(
            name: name,
            role: json['role'] as String? ?? '',
            systemPrompt: json['systemPrompt'] as String? ?? '',
            skills: (json['skills'] as List?)?.cast<String>() ?? const [],
            rules: (json['rules'] as List?)?.cast<String>() ?? const [],
            hooks: (json['hooks'] as List?)?.cast<String>() ?? const [],
            tools: (json['tools'] as List?)?.cast<String>() ?? const [],
            mcpServers:
                (json['mcpServers'] as List?)?.cast<String>() ?? const [],
            knowledgeBaseNames:
                (json['knowledgeBaseNames'] as List?)?.cast<String>() ??
                const [],
            canManageSystem: json['canManageSystem'] as bool? ?? false,
            provider: provider,
            model: json['model'] as String? ?? 'sonnet',
            effort: json['effort'] as String? ?? 'medium',
          )
        : profiles.updateProfile(
            existing.id,
            name: name,
            role: json['role'] as String? ?? '',
            systemPrompt: json['systemPrompt'] as String? ?? '',
            skills: (json['skills'] as List?)?.cast<String>() ?? const [],
            rules: (json['rules'] as List?)?.cast<String>() ?? const [],
            hooks: (json['hooks'] as List?)?.cast<String>() ?? const [],
            tools: (json['tools'] as List?)?.cast<String>() ?? const [],
            mcpServers:
                (json['mcpServers'] as List?)?.cast<String>() ?? const [],
            knowledgeBaseNames:
                (json['knowledgeBaseNames'] as List?)?.cast<String>() ??
                const [],
            canManageSystem: json['canManageSystem'] as bool? ?? false,
            provider: provider,
            model: json['model'] as String? ?? existing.model,
            effort: json['effort'] as String? ?? existing.effort,
          );
    track(error, existed: existing != null, label: 'agente $name');
  }

  final projects = ProjectsService.instance.notifier;
  final liveProfiles = profiles.data.profiles;
  final liveWorkflows = workflows.data.workflows;
  for (final json in byCategory['projects'] ?? const <Map<String, dynamic>>[]) {
    final name = json['name'] as String;
    final profileIds = [
      for (final handle
          in (json['agentHandles'] as List?)?.cast<String>() ?? const [])
        liveProfiles.where((profile) => profile.name == handle).firstOrNull?.id,
    ].whereType<String>().toList();
    final workflowIds = [
      for (final workflowName
          in (json['workflowNames'] as List?)?.cast<String>() ?? const [])
        liveWorkflows
            .where((workflow) => workflow.name == workflowName)
            .firstOrNull
            ?.id,
    ].whereType<String>().toList();
    final ruleNames =
        (json['ruleNames'] as List?)?.cast<String>() ?? const <String>[];
    final hookNames =
        (json['hookNames'] as List?)?.cast<String>() ?? const <String>[];
    final knowledgeBaseNames =
        (json['knowledgeBaseNames'] as List?)?.cast<String>() ??
        const <String>[];
    final maintained = json['maintained'] as bool? ?? true;

    final existing = projects.data.projects
        .where((project) => project.name == name)
        .firstOrNull;
    final error = existing == null
        // Imported projects arrive WITHOUT a working directory — the UI
        // asks for one when the project is opened (paths never travel).
        ? projects.createProject(
            name: name,
            purpose: json['purpose'] as String? ?? '',
            workingDirectory: '',
            profileIds: profileIds,
            workflowIds: workflowIds,
            ruleNames: ruleNames,
            hookNames: hookNames,
            knowledgeBaseNames: knowledgeBaseNames,
            maintained: maintained,
          )
        : projects.updateProject(
            existing.id,
            name: name,
            purpose: json['purpose'] as String? ?? '',
            workingDirectory: existing.workingDirectory,
            profileIds: profileIds,
            workflowIds: workflowIds,
            ruleNames: ruleNames,
            hookNames: hookNames,
            knowledgeBaseNames: knowledgeBaseNames,
            maintained: maintained,
          );
    track(error, existed: existing != null, label: 'proyecto $name');
    if (error != null) continue;

    // Los ajustes de motor van después de crear/actualizar: se guardan por
    // id de perfil, que de este lado es otro.
    final projectId =
        existing?.id ??
        projects.data.projects
            .where((project) => project.name == name)
            .firstOrNull
            ?.id;
    if (projectId == null) continue;
    for (final entry in _readEngines(json['memberEngines'])) {
      final profileId = liveProfiles
          .where((profile) => profile.name == entry.key)
          .firstOrNull
          ?.id;
      if (profileId == null) continue;
      projects.setMemberTuning(
        projectId,
        profileId,
        provider: entry.value.provider,
        model: entry.value.model,
        effort: entry.value.effort,
      );
    }
  }

  // Los requerimientos se CREAN si faltan y no se pisan si están. Un
  // requerimiento es una conversación viva: restaurarle encima la foto del
  // respaldo borraría todo lo que se dijo desde entonces.
  final requirements = RequirementsService.instance.notifier;
  for (final json
      in byCategory['requirements'] ?? const <Map<String, dynamic>>[]) {
    final code = json['name'] as String?;
    if (code == null || code.isEmpty) continue;
    if (requirements.byCode(code) != null) continue;

    String? idOf(Object? name) => projects.data.projects
        .where((project) => project.name == name)
        .firstOrNull
        ?.id;
    final fromId = idOf(json['fromProject']);
    final toId = idOf(json['toProject']);
    if (fromId == null || toId == null) {
      problems.add(
        'requerimiento $code: no existe '
        '${fromId == null ? json['fromProject'] : json['toProject']} de este '
        'lado',
      );
      continue;
    }

    final createdAt =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now();
    final imported = requirements.importSnapshot(
      InternalRequirement(
        id: generateUuidV4(),
        code: code,
        title: json['title'] as String? ?? code,
        fromProjectId: fromId,
        toProjectId: toId,
        need: json['need'] as String? ?? '',
        context: json['context'] as String? ?? '',
        blocking: json['blocking'] as bool? ?? false,
        openedByHandle: json['openedByHandle'] as String? ?? '',
        // Las sesiones son de esta máquina: no viajan y no se inventan.
        openedInSessionId: '',
        takenByHandle: json['takenByHandle'] as String?,
        status: RequirementStatus.fromAlias(json['status'] as String? ?? ''),
        verdict: json['verdict'] == null
            ? null
            : RequirementVerdict.fromJson(
                (json['verdict'] as Map).cast<String, dynamic>(),
              ),
        thread: (json['thread'] as List? ?? const [])
            .map(
              (entry) => RequirementEntry.fromJson(
                (entry as Map).cast<String, dynamic>(),
              ),
            )
            .toList(),
        createdAt: createdAt,
        updatedAt:
            DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? createdAt,
      ),
    );
    if (imported) created++;
  }

  // Los tableros se crean o se actualizan por (proyecto, nombre), como
  // todo lo demás. Un tablero cuyo proyecto no existe de este lado no se
  // inventa: se nombra, porque sin directorio de trabajo no prueba nada.
  final boards = BoardsService.instance.notifier;
  for (final json in byCategory['boards'] ?? const <Map<String, dynamic>>[]) {
    final boardName = json['board'] as String?;
    final projectName = json['project'] as String?;
    if (boardName == null || projectName == null) continue;

    final project = projects.data.projects
        .where((candidate) => candidate.name == projectName)
        .firstOrNull;
    if (project == null) {
      problems.add(
        'tablero $boardName: no existe el proyecto $projectName de este lado',
      );
      continue;
    }

    final existing = boards.boardNamed(project.id, boardName);
    final createdAt =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now();
    boards.upsert(
      Board(
        id: existing?.id ?? generateUuidV4(),
        projectId: project.id,
        name: boardName,
        note: json['note'] as String? ?? '',
        fields: [
          for (final field in json['fields'] as List? ?? const [])
            BoardField.fromJson((field as Map).cast<String, dynamic>()),
        ],
        actions: [
          for (final action in json['actions'] as List? ?? const [])
            BoardAction.fromJson((action as Map).cast<String, dynamic>()),
        ],
        createdByProfileId: existing?.createdByProfileId ?? '',
        createdAt: existing?.createdAt ?? createdAt,
        updatedAt:
            DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? createdAt,
      ),
    );
    if (existing == null) {
      created++;
    } else {
      updated++;
    }
  }

  final catalogLocks = CatalogLocksService.instance.notifier;
  for (final json
      in byCategory['catalog_locks'] ?? const <Map<String, dynamic>>[]) {
    final kind = CatalogLockKind.tryFromAlias(json['kind'] as String? ?? '');
    final itemName = json['itemName'] as String?;
    if (kind == null || itemName == null || itemName.isEmpty) {
      problems.add('candado inválido');
      continue;
    }
    await catalogLocks.setLocked(kind, itemName, locked: true);
    created++;
  }

  final parts = [
    'Importé el catálogo: $created creados, $updated actualizados.',
    if (problems.isNotEmpty) 'Problemas:\n- ${problems.join('\n- ')}',
    'Los proyectos nuevos necesitan su carpeta de trabajo: se pide al '
        'abrirlos.',
  ];
  return parts.join('\n');
}

/// Mirrors `kKeelAiSkillName` without importing the assistant module into
/// this integration — same literal, asserted by the export test of reading
/// the seed. Kept here to avoid a modules→assistant dependency for one
/// constant.
const kKeelAiSkillNameForExport = 'keelai-mapa-del-sistema';

/// El respaldo escribió `stations` hasta que un proyecto pasó a llamarse
/// proyecto.
///
/// Un `.zip` hecho antes de ese cambio sigue siendo un respaldo válido, así
/// que su categoría vieja se lee bajo el nombre nuevo. Es un alias de
/// LECTURA solamente: al escribir siempre sale `projects`, para que el
/// formato viejo se apague solo en vez de quedar para siempre.
const kLegacyCategoryAliases = <String, String>{'stations': 'projects'};

/// [byCategory] con las categorías viejas renombradas a las de hoy. Si el
/// nombre nuevo ya viene en el mapa, gana ese: nunca pisa lo actual.
Map<String, T> withLegacyCategoryNames<T>(Map<String, T> byCategory) {
  if (!kLegacyCategoryAliases.keys.any(byCategory.containsKey)) {
    return byCategory;
  }
  final renamed = Map<String, T>.from(byCategory);
  for (final alias in kLegacyCategoryAliases.entries) {
    final legacy = renamed.remove(alias.key);
    if (legacy != null && !renamed.containsKey(alias.value)) {
      renamed[alias.value] = legacy;
    }
  }
  return renamed;
}
