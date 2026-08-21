part of '../catalog_sync.dart';

const _kCatalogDirs = [
  'skills',
  'rules',
  'tools',
  'workflows',
  'mcp_servers',
  'knowledge_bases',
  'profiles',
  'stations',
];

String _fileNameFor(String name) =>
    '${name.replaceAll(RegExp(r'[/\\:]'), '_')}.json';

Future<void> _writeEntity(
  Directory catalogDir,
  String category,
  String name,
  Map<String, dynamic> json,
) async {
  final file = File('${catalogDir.path}/$category/${_fileNameFor(name)}');
  await file.create(recursive: true);
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));
}

/// Serializes the live catalog into `<mirror>/catalog/…`, everything BY
/// NAME. Returns how many entities were written. The catalog dir is
/// recreated from scratch so deletions propagate too.
Future<int> _writeCatalog(Directory mirror) async {
  final catalogDir = Directory('${mirror.path}/catalog');
  if (catalogDir.existsSync()) await catalogDir.delete(recursive: true);
  for (final category in _kCatalogDirs) {
    await Directory('${catalogDir.path}/$category').create(recursive: true);
  }

  var written = 0;

  for (final skill in SkillsService.instance.notifier.data.skills) {
    // The system map is compiled app knowledge, re-seeded on every launch —
    // exporting it would just ship a stale copy.
    if (skill.name == kKeelAiSkillNameForExport) continue;
    await _writeEntity(catalogDir, 'skills', skill.name, {
      'name': skill.name,
      'content': skill.content,
      'isGlobal': skill.isGlobal,
    });
    written++;
  }

  for (final rule in RulesService.instance.notifier.data.rules) {
    await _writeEntity(catalogDir, 'rules', rule.name, {
      'name': rule.name,
      'content': rule.content,
    });
    written++;
  }

  for (final tool in ToolsService.instance.notifier.data.tools) {
    await _writeEntity(catalogDir, 'tools', tool.name, {
      'name': tool.name,
      'description': tool.description,
      'runtime': tool.runtime.alias,
      'code': tool.code,
      'timeoutSeconds': tool.timeoutSeconds,
      'secretNames': tool.secretNames,
    });
    written++;
  }

  for (final workflow in WorkflowsService.instance.notifier.data.workflows) {
    await _writeEntity(catalogDir, 'workflows', workflow.name, {
      'name': workflow.name,
      'whenToApply': workflow.whenToApply,
      'steps': [
        for (final step in workflow.steps)
          {
            'title': step.title,
            'role': step.role,
            'instruction': step.instruction,
          },
      ],
    });
    written++;
  }

  for (final server in McpServersService.instance.notifier.data.servers) {
    await _writeEntity(catalogDir, 'mcp_servers', server.name, {
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
    written++;
  }

  for (final base in KnowledgeService.instance.notifier.data.bases) {
    await _writeEntity(catalogDir, 'knowledge_bases', base.name, {
      'name': base.name,
      'description': base.description,
      'source': base.source.alias,
      'gitUrl': base.gitUrl,
      'gitBranch': base.gitBranch,
      // La ruta local NO viaja, igual que el directorio de una estación: al
      // importar la base queda sin carpeta y la UI la pide. El CONTENIDO
      // tampoco — un repo git se recupera clonando.
    });
    written++;
  }

  final profiles = AgentProfilesService.instance.notifier.data.profiles;
  for (final profile in profiles) {
    if (profile.name == kKeelAiHandle) continue;
    await _writeEntity(catalogDir, 'profiles', profile.name, {
      'name': profile.name,
      'role': profile.role,
      'systemPrompt': profile.systemPrompt,
      'skills': profile.skills,
      'rules': profile.rules,
      'tools': profile.tools,
      'mcpServers': profile.mcpServers,
      'knowledgeBaseNames': profile.knowledgeBaseNames,
      'canManageSystem': profile.canManageSystem,
      'provider': profile.provider.alias,
      'model': profile.model,
      'effort': profile.effort,
    });
    written++;
  }

  final stationsViewModel = StationsService.instance.notifier;
  for (final station in stationsViewModel.data.stations) {
    final workflows = WorkflowsService.instance.notifier.data.workflows;
    String? workflowNameOf(String id) =>
        workflows.where((workflow) => workflow.id == id).firstOrNull?.name;
    await _writeEntity(catalogDir, 'stations', station.name, {
      'name': station.name,
      'purpose': station.purpose,
      // Portable references only: handles and names. Working directory and
      // tasks are machine-local and NEVER exported.
      'agentHandles': [
        for (final id in station.profileIds)
          profiles.where((profile) => profile.id == id).firstOrNull?.name,
      ].whereType<String>().toList(),
      'workflowNames': station.workflowIds
          .map(workflowNameOf)
          .whereType<String>()
          .toList(),
      'ruleNames': station.ruleNames,
      'knowledgeBaseNames': station.knowledgeBaseNames,
      // Con qué motor corre cada miembro acá, por handle: es configuración de
      // la estación, así que viaja con ella o se pierde en el import.
      'memberEngines': _engineMirror(station, profiles),
      'activeWorkflowName': station.activeWorkflowId == null
          ? null
          : workflowNameOf(station.activeWorkflowId!),
    });
    written++;
  }

  return written;
}

/// Los ajustes de motor de [station] rekeyados por handle. Un ajuste de un
/// perfil que ya no existe no se escribe: el mirror es portable y un id
/// suelto no significa nada del otro lado.
Map<String, dynamic> _engineMirror(
  Station station,
  List<AgentProfile> profiles,
) {
  final mirror = <String, dynamic>{};
  for (final entry in station.memberTuning.entries) {
    final handle = profiles
        .where((profile) => profile.id == entry.key)
        .firstOrNull
        ?.name;
    if (handle == null) continue;
    mirror[handle] = entry.value.toJson();
  }
  return mirror;
}

/// Los ajustes de motor de un archivo de estación, por handle. Un mirror
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

List<Map<String, dynamic>> _readCategory(Directory mirror, String category) {
  final dir = Directory('${mirror.path}/catalog/$category');
  if (!dir.existsSync()) return const [];
  final entries = <Map<String, dynamic>>[];
  for (final entity in dir.listSync()) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;
    try {
      entries.add(
        jsonDecode(entity.readAsStringSync()) as Map<String, dynamic>,
      );
    } catch (error) {
      Log.w('Catálogo: no pude leer ${entity.path}: $error');
    }
  }
  return entries;
}

/// Merges the repo catalog into the live one, by name: create if missing,
/// update in place if present. Returns the human summary.
Future<String> _readAndMergeCatalog(Directory mirror) async {
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
  for (final json in _readCategory(mirror, 'skills')) {
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
  for (final json in _readCategory(mirror, 'rules')) {
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

  final tools = ToolsService.instance.notifier;
  for (final json in _readCategory(mirror, 'tools')) {
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
  for (final json in _readCategory(mirror, 'workflows')) {
    final name = json['name'] as String;
    final steps = [
      for (final step
          in (json['steps'] as List?)?.cast<Map<String, dynamic>>() ??
              const <Map<String, dynamic>>[])
        WorkflowStep(
          id: generateUuidV4(),
          title: step['title'] as String? ?? '',
          role: step['role'] as String? ?? '',
          instruction: step['instruction'] as String? ?? '',
        ),
    ];
    final existing = workflows.data.workflows
        .where((workflow) => workflow.name == name)
        .firstOrNull;
    final error = existing == null
        ? workflows.createWorkflow(
            name: name,
            whenToApply: json['whenToApply'] as String? ?? '',
            steps: steps,
          )
        : workflows.updateWorkflow(
            existing.id,
            name: name,
            whenToApply: json['whenToApply'] as String? ?? '',
            steps: steps,
          );
    track(error, existed: existing != null, label: 'workflow $name');
  }

  final servers = McpServersService.instance.notifier;
  for (final json in _readCategory(mirror, 'mcp_servers')) {
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
  for (final json in _readCategory(mirror, 'knowledge_bases')) {
    final name = json['name'] as String;
    final source = KnowledgeSource.tryFromAlias(
      json['source'] as String? ?? '',
    );
    if (source == null) {
      problems.add('base de saber $name: fuente inválida');
      continue;
    }
    final existing = knowledge.baseByName(name);
    final error = existing == null
        ? knowledge.createBase(
            name: name,
            description: json['description'] as String? ?? '',
            source: source,
            gitUrl: json['gitUrl'] as String? ?? '',
            gitBranch: json['gitBranch'] as String? ?? '',
          )
        : knowledge.updateBase(
            existing.id,
            name: name,
            description: json['description'] as String? ?? '',
            source: source,
            gitUrl: json['gitUrl'] as String? ?? '',
            gitBranch: json['gitBranch'] as String? ?? '',
            // La carpeta que ya tenga en ESTA máquina se respeta: la ruta
            // nunca viaja, así que la del repo sería siempre vacía.
            localPath: existing.localPath,
          );
    track(error, existed: existing != null, label: 'base de saber $name');
  }

  final profiles = AgentProfilesService.instance.notifier;
  for (final json in _readCategory(mirror, 'profiles')) {
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

  final stations = StationsService.instance.notifier;
  final liveProfiles = profiles.data.profiles;
  final liveWorkflows = workflows.data.workflows;
  for (final json in _readCategory(mirror, 'stations')) {
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
    final knowledgeBaseNames =
        (json['knowledgeBaseNames'] as List?)?.cast<String>() ??
        const <String>[];

    final existing = stations.data.stations
        .where((station) => station.name == name)
        .firstOrNull;
    final error = existing == null
        // Imported stations arrive WITHOUT a working directory — the UI
        // asks for one when the station is opened (paths never travel).
        ? stations.createStation(
            name: name,
            purpose: json['purpose'] as String? ?? '',
            workingDirectory: '',
            profileIds: profileIds,
            workflowIds: workflowIds,
            ruleNames: ruleNames,
            knowledgeBaseNames: knowledgeBaseNames,
          )
        : stations.updateStation(
            existing.id,
            name: name,
            purpose: json['purpose'] as String? ?? '',
            workingDirectory: existing.workingDirectory,
            profileIds: profileIds,
            workflowIds: workflowIds,
            ruleNames: ruleNames,
            knowledgeBaseNames: knowledgeBaseNames,
          );
    track(error, existed: existing != null, label: 'estación $name');
    if (error != null) continue;

    // Los ajustes de motor van después de crear/actualizar: se guardan por
    // id de perfil, que de este lado es otro.
    final stationId =
        existing?.id ??
        stations.data.stations
            .where((station) => station.name == name)
            .firstOrNull
            ?.id;
    if (stationId == null) continue;
    for (final entry in _readEngines(json['memberEngines'])) {
      final profileId = liveProfiles
          .where((profile) => profile.name == entry.key)
          .firstOrNull
          ?.id;
      if (profileId == null) continue;
      stations.setMemberTuning(
        stationId,
        profileId,
        provider: entry.value.provider,
        model: entry.value.model,
        effort: entry.value.effort,
      );
    }
  }

  final parts = [
    'Importé el catálogo: $created creados, $updated actualizados.',
    if (problems.isNotEmpty) 'Problemas:\n- ${problems.join('\n- ')}',
    'Las estaciones nuevas necesitan su carpeta de trabajo, y las bases de '
        'saber locales su carpeta: se piden al abrirlas.',
  ];
  return parts.join('\n');
}

/// Mirrors `kKeelAiSkillName` without importing the assistant module into
/// this integration — same literal, asserted by the export test of reading
/// the seed. Kept here to avoid a modules→assistant dependency for one
/// constant.
const kKeelAiSkillNameForExport = 'keelai-mapa-del-sistema';
