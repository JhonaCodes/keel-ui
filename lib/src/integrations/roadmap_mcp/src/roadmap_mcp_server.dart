part of '../roadmap_mcp.dart';

const kRoadmapMcpServerKey = 'keel-roadmap';
const kRoadmapMcpToolPrefix = 'mcp__${kRoadmapMcpServerKey}__';

/// Las tres tools que ve un miembro de proyecto cuyo proyecto tiene roadmap.
const kRoadmapMcpToolNames = [
  '${kRoadmapMcpToolPrefix}list_roadmap_tasks',
  '${kRoadmapMcpToolPrefix}claim_task',
  '${kRoadmapMcpToolPrefix}release_task',
];

/// Servidor MCP local que le da a un turno el roadmap de SU proyecto.
///
/// La ruta lleva proyecto y perfil, así que el proyecto queda fijado del lado
/// de la app: el modelo no manda una ruta de proyecto y por lo tanto no puede
/// equivocarse de repo ni cruzar tareas de otro.
///
/// Una instancia nueva por POST, igual que los otros servidores locales: el
/// CLI corre el handshake dos veces por invocación.
class RoadmapMcpServer {
  RoadmapMcpServer._();

  static HttpServer? _server;
  static String? _token;

  static Future<void> ensureStarted() async {
    if (_server != null) return;
    _token = _generateToken();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    unawaited(server.forEach(_handleRequest));
    Log.i('Roadmap MCP server on 127.0.0.1:${server.port}');
  }

  /// La entrada de config para el turno de [profileId] en [projectId], o null
  /// si el servidor no levantó o el proyecto no tiene carpeta de roadmap.
  ///
  /// Devolver null cuando no hay `TASKS/` es deliberado: un proyecto sin
  /// roadmap no debería ver tres tools que no aplican.
  static Map<String, dynamic>? mcpServerEntryFor({
    required String projectId,
    required String sessionId,
    required String profileId,
    required String workingDirectory,
  }) {
    final server = _server;
    final token = _token;
    if (server == null || token == null) return null;
    if (workingDirectory.trim().isEmpty) return null;
    if (!Directory('$workingDirectory/$kRoadmapFolder').existsSync()) {
      return null;
    }

    final uri = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: server.port,
      pathSegments: ['roadmap', projectId, sessionId, profileId],
    );
    return {
      'type': 'http',
      'url': uri.toString(),
      'headers': {'Authorization': 'Bearer $token'},
    };
  }

  static Future<void> _handleRequest(HttpRequest request) async {
    final token = _token;
    if (token == null ||
        request.headers.value('authorization') != 'Bearer $token') {
      request.response.statusCode = HttpStatus.unauthorized;
      await request.response.close();
      return;
    }

    final segments = request.uri.pathSegments;
    if (request.method != 'POST' ||
        segments.length != 4 ||
        segments[0] != 'roadmap') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final body = await utf8.decoder.bind(request).join();
    Map<String, dynamic> message;
    try {
      message = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final id = message['id'];
    final method = message['method'] as String?;

    if (id == null) {
      request.response.statusCode = HttpStatus.accepted;
      await request.response.close();
      return;
    }

    if (method != mcp.InitializeRequest.methodName &&
        method != mcp.ListToolsRequest.methodName &&
        method != mcp.CallToolRequest.methodName) {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': id,
          'error': {'code': -32601, 'message': 'Method not found: $method'},
        }),
      );
      await request.response.close();
      return;
    }

    final controller = StreamChannelController<String>();
    _RoadmapMcpServer(
      controller.foreign,
      projectId: segments[1],
      sessionId: segments[2],
      profileId: segments[3],
      willInitialize: method == mcp.InitializeRequest.methodName,
    );

    final replyCompleter = Completer<String>();
    controller.local.stream.listen(
      (data) {
        if (!replyCompleter.isCompleted) replyCompleter.complete(data);
      },
      onError: (Object error) {
        if (!replyCompleter.isCompleted) replyCompleter.completeError(error);
      },
    );
    controller.local.sink.add(jsonEncode(message));

    final reply = await replyCompleter.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'error': {'code': -32000, 'message': 'Roadmap MCP server timed out'},
      }),
    );
    await controller.local.sink.close();

    request.response.headers.contentType = ContentType.json;
    request.response.write(reply);
    await request.response.close();
  }

  static String _generateToken() {
    final random = Random.secure();
    return List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

final class _RoadmapMcpServer extends mcp.MCPServer with mcp.ToolsSupport {
  _RoadmapMcpServer(
    super.channel, {
    required this.projectId,
    required this.sessionId,
    required this.profileId,
    required bool willInitialize,
  }) : super.fromStreamChannel(
         implementation: mcp.Implementation(
           name: kRoadmapMcpServerKey,
           version: '1.0.0',
         ),
         instructions:
             'El roadmap de este proyecto. Antes de trabajar en una tarea, '
             'tomala: si otro la tiene, pasá a la siguiente.',
       ) {
    registerTool(_listTool, _list);
    registerTool(_claimTool, _claim);
    registerTool(_releaseTool, _release);
    if (!willInitialize) {
      registerRequestHandler(mcp.ListToolsRequest.methodName, listTools);
      registerRequestHandler(mcp.CallToolRequest.methodName, callTool);
    }
  }

  final String projectId;
  final String sessionId;
  final String profileId;

  TaskClaimsViewModel get _claims => TaskClaimsService.instance.notifier;

  ({String path, String name})? get _project {
    final project = ProjectsService.instance.notifier.data.projects
        .where((entry) => entry.id == projectId)
        .firstOrNull;
    if (project == null) return null;
    final path = project.workingDirectory.trim();
    if (path.isEmpty) return null;
    return (path: path, name: project.name);
  }

  /// El título de la sesión donde corre este turno, para que la toma se
  /// pueda mostrar sin resolver un id contra nada.
  String get _sessionTitle {
    final project = ProjectsService.instance.notifier.data.projects
        .where((entry) => entry.id == projectId)
        .firstOrNull;
    return project?.sessions
            .where((session) => session.id == sessionId)
            .firstOrNull
            ?.title ??
        '';
  }

  String get _handle =>
      AgentProfilesService.instance.notifier.data.profiles
          .where((profile) => profile.id == profileId)
          .firstOrNull
          ?.name ??
      'desconocido';

  static final _listTool = mcp.Tool(
    name: 'list_roadmap_tasks',
    description:
        'El roadmap de este proyecto: cada tarea con su estado, sus '
        'bloqueantes y si alguien la tiene tomada. Se lee del disco en cada '
        'llamada, así que refleja lo que haya ahora — incluido lo que otro '
        'acaba de agregar. Llamala ANTES de elegir en qué trabajar.',
    inputSchema: mcp.ObjectSchema(
      properties: {
        'solo_tomables': mcp.Schema.bool(
          description:
              'Si true, devuelve solo las que podés tomar ya: ni hechas, ni '
              'bloqueadas, ni tomadas por otro. Por defecto false.',
        ),
      },
    ),
  );

  static final _claimTool = mcp.Tool(
    name: 'claim_task',
    description:
        'Toma una tarea para vos. Es atómico: si otro se te adelantó, falla '
        'y te dice quién la tiene — ahí pasá a la siguiente, no insistas. La '
        'toma vence sola a los 30 minutos; volver a llamarla sobre la misma '
        'tarea la renueva.',
    inputSchema: mcp.ObjectSchema(
      properties: {
        'task_path': mcp.Schema.string(
          description:
              'La ruta que devolvió list_roadmap_tasks, tal cual: '
              '"01-fundacion/02-shell.md".',
        ),
      },
      required: ['task_path'],
    ),
  );

  static final _releaseTool = mcp.Tool(
    name: 'release_task',
    description:
        'Suelta una tarea que tomaste, al terminarla o al abandonarla. Solo '
        'podés soltar las tuyas.',
    inputSchema: mcp.ObjectSchema(
      properties: {
        'task_path': mcp.Schema.string(description: 'La ruta de la tarea.'),
      },
      required: ['task_path'],
    ),
  );

  Future<mcp.CallToolResult> _list(mcp.CallToolRequest request) async {
    final project = _project;
    if (project == null) {
      return _text('Este proyecto no tiene carpeta de trabajo asignada.');
    }

    _claims.pruneExpired();
    final tasks = readRoadmap(project.path);
    if (tasks.isEmpty) {
      return _text(
        'El proyecto no tiene tareas en $kRoadmapFolder/, o la carpeta está '
        'vacía.',
      );
    }

    final soloTomables = request.arguments?['solo_tomables'] as bool? ?? false;
    final salida = <Map<String, dynamic>>[];

    for (final task in tasks) {
      final claim = _claims.claimOf(project.path, task.path);
      final tomable = task.isTakeable && claim == null;
      if (soloTomables && !tomable) continue;

      salida.add({
        'ruta': task.path,
        'carpeta': task.folder,
        'titulo': task.title,
        'estado': task.state.alias,
        'borrador': task.isDraft,
        'tomable': tomable,
        if (task.brokenBlockers.isNotEmpty)
          'referencias_rotas': [
            for (final blocker in task.brokenBlockers)
              '${blocker.reference} (${blocker.target.name})',
          ],
        if (claim != null)
          'tomada_por': '${claim.profileHandle} (${claim.projectName})',
        if (task.blockers.isNotEmpty)
          'bloqueantes': [
            for (final blocker in task.blockers) blocker.toJson(),
          ],
      });
    }

    if (salida.isEmpty) {
      return _text(
        'No hay ninguna tarea tomable ahora: están hechas, bloqueadas o '
        'tomadas por otro.',
      );
    }
    return _text(jsonEncode({'proyecto': project.name, 'tareas': salida}));
  }

  Future<mcp.CallToolResult> _claim(mcp.CallToolRequest request) async {
    final project = _project;
    if (project == null) {
      return _text('Este proyecto no tiene carpeta de trabajo asignada.');
    }

    final taskPath = (request.arguments?['task_path'] as String? ?? '').trim();
    if (taskPath.isEmpty) return _text('Falta task_path.');

    // La tarea tiene que existir de verdad: tomar una ruta inventada dejaría
    // un candado sobre algo que nadie va a hacer.
    final task = readRoadmap(
      project.path,
    ).where((entry) => entry.path == taskPath).firstOrNull;
    if (task == null) {
      return _text(
        'No existe "$taskPath" en el roadmap. Pedí list_roadmap_tasks y usá '
        'una ruta de ahí.',
      );
    }
    if (task.state == RoadmapState.hecho) {
      return _text('"$taskPath" ya está hecha.');
    }
    // Una referencia rota se avisa ANTES que un bloqueante abierto: es un
    // error del roadmap, no una dependencia legítima, y nadie puede
    // destrabarla terminando algo.
    if (task.brokenBlockers.isNotEmpty) {
      final rotas = task.brokenBlockers
          .map(
            (blocker) => blocker.target == BlockerTarget.ambiguous
                ? '"${blocker.reference}" coincide con más de una tarea'
                : '"${blocker.reference}" no existe',
          )
          .join('; ');
      return _text(
        'El roadmap está roto en "$taskPath": $rotas. Alguien renombró o '
        'renumeró una tarea sin arrastrar la referencia. Arreglala en la '
        'sección Bloqueantes del archivo —o borrá el bloqueante si la '
        'dependencia ya no existe— y volvé a intentar. No la tomo así '
        'porque no se puede saber si la dependencia desapareció o solo '
        'cambió de nombre.',
      );
    }
    if (task.hasOpenBlockers) {
      final abiertos = task.blockers
          .where((blocker) => !blocker.resolved && !blocker.isBroken)
          .map((blocker) => blocker.reference)
          .join(', ');
      return _text(
        'No se puede tomar todavía: primero hay que resolver $abiertos.',
      );
    }

    final result = _claims.claimTask(
      projectPath: project.path,
      projectName: project.name,
      taskPath: taskPath,
      title: task.title,
      profileHandle: _handle,
      sessionId: sessionId,
      sessionTitle: _sessionTitle,
    );
    if (result.error != null) return _text(result.error!);

    return _text(
      'Tomaste "${task.title}" ($taskPath). Es tuya por 30 minutos; volvé a '
      'llamar claim_task para renovarla si seguís. Cuando la termines, marcá '
      'estado: hecho en el archivo y llamá release_task.',
    );
  }

  Future<mcp.CallToolResult> _release(mcp.CallToolRequest request) async {
    final project = _project;
    if (project == null) {
      return _text('Este proyecto no tiene carpeta de trabajo asignada.');
    }

    final taskPath = (request.arguments?['task_path'] as String? ?? '').trim();
    if (taskPath.isEmpty) return _text('Falta task_path.');

    final error = _claims.releaseTask(
      projectPath: project.path,
      taskPath: taskPath,
      profileHandle: _handle,
    );
    if (error != null) return _text(error);
    return _text('Soltaste "$taskPath".');
  }

  mcp.CallToolResult _text(String message) =>
      mcp.CallToolResult(content: [mcp.TextContent(text: message)]);
}
