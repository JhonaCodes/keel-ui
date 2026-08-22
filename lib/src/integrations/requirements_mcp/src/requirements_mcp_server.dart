part of '../requirements_mcp.dart';

const kRequirementsMcpServerKey = 'keel-requirements';
const kRequirementsMcpToolPrefix = 'mcp__${kRequirementsMcpServerKey}__';

/// Lo que ve un miembro de proyecto para pedirle cosas a otro proyecto.
const kRequirementsMcpToolNames = [
  '${kRequirementsMcpToolPrefix}list_requirements',
  '${kRequirementsMcpToolPrefix}create_requirement',
  '${kRequirementsMcpToolPrefix}take_requirement',
  '${kRequirementsMcpToolPrefix}record_verdict',
  '${kRequirementsMcpToolPrefix}reply_requirement',
  '${kRequirementsMcpToolPrefix}request_closure',
  '${kRequirementsMcpToolPrefix}close_requirement',
  '${kRequirementsMcpToolPrefix}ask_project',
];

/// Servidor MCP local con los requerimientos de ESTE proyecto.
///
/// La ruta lleva proyecto, sesión y perfil. De ahí sale de qué lado está
/// parado el que llama, y por eso "cerrar es del origen" se puede comprobar
/// en vez de pedir: un turno del destino no tiene cómo decir que es el origen.
class RequirementsMcpServer {
  RequirementsMcpServer._();

  static HttpServer? _server;
  static String? _token;

  static Future<void> ensureStarted() async {
    if (_server != null) return;
    _token = _generateToken();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    unawaited(server.forEach(_handleRequest));
    Log.i('Requirements MCP server on 127.0.0.1:${server.port}');
  }

  /// La entrada de config para este turno, o null si no hay con quién
  /// hablar: con un solo proyecto registrado no existe "otro proyecto", y
  /// ofrecer siete tools que no se pueden usar es ruido.
  static Map<String, dynamic>? mcpServerEntryFor({
    required String projectId,
    required String sessionId,
    required String profileId,
  }) {
    final server = _server;
    final token = _token;
    if (server == null || token == null) return null;
    if (ProjectsService.instance.notifier.data.projects.length < 2) return null;

    final uri = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: server.port,
      pathSegments: ['requirements', projectId, sessionId, profileId],
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
        segments[0] != 'requirements') {
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
          'error': {'code': -32601, 'message': 'Method not supported'},
        }),
      );
      await request.response.close();
      return;
    }

    final controller = StreamChannelController<String>(sync: true);
    _RequirementsMcpServer(
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
        'error': {
          'code': -32000,
          'message': 'Requirements MCP server timed out',
        },
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

final class _RequirementsMcpServer extends mcp.MCPServer with mcp.ToolsSupport {
  _RequirementsMcpServer(
    super.channel, {
    required this.projectId,
    required this.sessionId,
    required this.profileId,
    required bool willInitialize,
  }) : super.fromStreamChannel(
         implementation: mcp.Implementation(
           name: kRequirementsMcpServerKey,
           version: '1.0.0',
         ),
         instructions:
             'Lo que este proyecto le pide a otros y lo que otros le piden a '
             'él. Cerrar un requerimiento es de quien lo abrió: del otro lado '
             'se PIDE el cierre, con justificación.',
       ) {
    registerTool(_listTool, _list);
    registerTool(_createTool, _create);
    registerTool(_takeTool, _take);
    registerTool(_verdictTool, _verdict);
    registerTool(_replyTool, _reply);
    registerTool(_requestClosureTool, _requestClosure);
    registerTool(_closeTool, _close);
    registerTool(_askTool, _ask);
    if (!willInitialize) {
      registerRequestHandler(mcp.ListToolsRequest.methodName, listTools);
      registerRequestHandler(mcp.CallToolRequest.methodName, callTool);
    }
  }

  final String projectId;
  final String sessionId;
  final String profileId;

  RequirementsViewModel get _requirements =>
      RequirementsService.instance.notifier;

  Project? get _project => ProjectsService.instance.notifier.data.projects
      .where((project) => project.id == projectId)
      .firstOrNull;

  String get _handle =>
      AgentProfilesService.instance.notifier.data.profiles
          .where((profile) => profile.id == profileId)
          .firstOrNull
          ?.name ??
      'desconocido';

  String _nameOf(String id) =>
      ProjectsService.instance.notifier.data.projects
          .where((project) => project.id == id)
          .firstOrNull
          ?.name ??
      'proyecto eliminado';

  // ── tools ───────────────────────────────────────────────────────────

  static final _listTool = mcp.Tool(
    name: 'list_requirements',
    description:
        'Los requerimientos de este proyecto, en las dos direcciones: lo que '
        'pidió y lo que le piden. Llamalo ANTES de abrir uno nuevo — puede '
        'que ya esté pedido.',
    inputSchema: mcp.ObjectSchema(
      properties: {
        'solo_abiertos': mcp.Schema.bool(
          description: 'Si true, oculta los cerrados y cancelados.',
        ),
      },
    ),
  );

  static final _createTool = mcp.Tool(
    name: 'create_requirement',
    description:
        'Abre un requerimiento hacia OTRO proyecto: algo que necesitás y que '
        'no está de tu lado. FALLA si ese proyecto no está registrado en '
        'keel-ui — en ese caso no inventes nada: decilo en tu respuesta y '
        'pedí que lo registren.',
    inputSchema: mcp.ObjectSchema(
      properties: {
        'proyecto': mcp.Schema.string(
          description: 'Nombre del proyecto al que se lo pedís.',
        ),
        'titulo': mcp.Schema.string(description: 'Una línea.'),
        'necesita': mcp.Schema.string(
          description: 'Qué necesitás, concreto y verificable.',
        ),
        'contexto': mcp.Schema.string(
          description:
              'Qué hiciste y por qué lo necesitás. Es la mitad que le permite '
              'al otro lado decidir sin preguntarte tres veces.',
        ),
        'bloquea': mcp.Schema.bool(
          description: 'Si tu trabajo queda frenado esperando esto.',
        ),
      },
      required: ['proyecto', 'titulo', 'necesita'],
    ),
  );

  static final _takeTool = mcp.Tool(
    name: 'take_requirement',
    description:
        'Toma un requerimiento que le llegó a este proyecto, para evaluarlo.',
    inputSchema: mcp.ObjectSchema(
      properties: {'codigo': mcp.Schema.string(description: 'REQ-0007')},
      required: ['codigo'],
    ),
  );

  static final _verdictTool = mcp.Tool(
    name: 'record_verdict',
    description:
        'Deja el dictamen de un requerimiento que tomaste, DESPUÉS de mirarlo '
        'contra tu propio roadmap y antes de ponerte a construir.',
    inputSchema: mcp.ObjectSchema(
      properties: {
        'codigo': mcp.Schema.string(),
        'veredicto': mcp.Schema.string(
          description:
              'viable | bloqueado | no-viable | ya-resuelto. "ya-resuelto" es '
              'cuando eso ya existe pero de otra forma que la que pidieron: '
              'explicá cuál en la razón.',
        ),
        'razon': mcp.Schema.string(),
        'antes_hay_que': mcp.Schema.list(
          items: mcp.Schema.string(),
          description: 'Si es "bloqueado": qué va primero, nombrado.',
        ),
      },
      required: ['codigo', 'veredicto', 'razon'],
    ),
  );

  static final _replyTool = mcp.Tool(
    name: 'reply_requirement',
    description:
        'Escribe en el hilo compartido de un requerimiento. Es lo ÚNICO que '
        'cruza entre los dos proyectos.',
    inputSchema: mcp.ObjectSchema(
      properties: {'codigo': mcp.Schema.string(), 'texto': mcp.Schema.string()},
      required: ['codigo', 'texto'],
    ),
  );

  static final _requestClosureTool = mcp.Tool(
    name: 'request_closure',
    description:
        'PIDE que se cierre un requerimiento que te pidieron, con una '
        'justificación clara. No lo cierra: cerrar es de quien lo abrió, que '
        'es el único que sabe si lo que necesitaba está.',
    inputSchema: mcp.ObjectSchema(
      properties: {
        'codigo': mcp.Schema.string(),
        'justificacion': mcp.Schema.string(),
      },
      required: ['codigo', 'justificacion'],
    ),
  );

  static final _closeTool = mcp.Tool(
    name: 'close_requirement',
    description:
        'Cierra un requerimiento que abrió ESTE proyecto, porque lo que '
        'necesitaba ya está. Solo funciona del lado que lo abrió.',
    inputSchema: mcp.ObjectSchema(
      properties: {'codigo': mcp.Schema.string(), 'nota': mcp.Schema.string()},
      required: ['codigo'],
    ),
  );

  static final _askTool = mcp.Tool(
    name: 'ask_project',
    description:
        'Le PREGUNTA algo a otro proyecto: cómo es un endpoint, qué devuelve, '
        'si algo existe. Corre un agente aparte en ese repo, en lectura, y te '
        'devuelve solo su respuesta — vos no recibís acceso a esa carpeta. '
        'Usalo antes de abrir un requerimiento: puede que lo que necesitás ya '
        'esté y solo no lo sabías.',
    inputSchema: mcp.ObjectSchema(
      properties: {
        'proyecto': mcp.Schema.string(description: 'Nombre del proyecto.'),
        'pregunta': mcp.Schema.string(
          description:
              'Concreta. Del otro lado no tienen tu contexto, así que una '
              'pregunta vaga vuelve con una respuesta vaga.',
        ),
      },
      required: ['proyecto', 'pregunta'],
    ),
  );

  Future<mcp.CallToolResult> _ask(mcp.CallToolRequest request) async {
    final target = (request.arguments?['proyecto'] as String? ?? '').trim();
    final question = (request.arguments?['pregunta'] as String? ?? '').trim();
    if (target.isEmpty || question.isEmpty) {
      return _text('Falta el proyecto o la pregunta.');
    }
    if (target.toLowerCase() == (_project?.name.toLowerCase() ?? '')) {
      return _text('Ese sos vos: leé el repo directamente.');
    }
    final answer = await ProjectsService.instance.notifier.askProject(
      toProjectName: target,
      question: question,
    );
    return _text('Contestó "$target":\n\n$answer');
  }

  // ── handlers ────────────────────────────────────────────────────────

  mcp.CallToolResult _list(mcp.CallToolRequest request) {
    final project = _project;
    if (project == null) return _text('Este proyecto ya no existe.');
    final soloAbiertos = request.arguments?['solo_abiertos'] as bool? ?? false;

    List<Map<String, dynamic>> render(List<InternalRequirement> items) => [
      for (final item in items)
        if (!soloAbiertos || item.status.isOpen)
          renderRequirement(
            item,
            fromProject: _nameOf(item.fromProjectId),
            toProject: _nameOf(item.toProjectId),
          ),
    ];

    return _text(
      jsonEncode({
        'proyecto': project.name,
        'pedidos_por_mi': render(_requirements.outgoingOf(projectId)),
        'me_piden': render(_requirements.incomingOf(projectId)),
      }),
    );
  }

  mcp.CallToolResult _create(mcp.CallToolRequest request) {
    final project = _project;
    if (project == null) return _text('Este proyecto ya no existe.');

    final target = (request.arguments?['proyecto'] as String? ?? '').trim();
    final registrado = ProjectsService.instance.notifier.data.projects
        .where((entry) => entry.name.toLowerCase() == target.toLowerCase())
        .firstOrNull;

    // LA COMPUERTA. Sin proyecto registrado no se abre nada, y se dice qué
    // hacer: el agente lo expresa en su respuesta en vez de inventar un
    // destinatario que no existe.
    if (registrado == null) {
      return _text(
        'No hay ningún proyecto registrado con el nombre "$target", así que '
        'NO abrí ningún requerimiento. Decilo en tu respuesta con lo que '
        'necesitás y pedí que se registre ese proyecto en keel-ui; cuando '
        'exista, volvé a intentarlo.',
      );
    }

    final result = _requirements.open(
      fromProjectId: projectId,
      toProjectId: registrado.id,
      title: request.arguments?['titulo'] as String? ?? '',
      need: request.arguments?['necesita'] as String? ?? '',
      context: request.arguments?['contexto'] as String? ?? '',
      openedByHandle: _handle,
      openedInSessionId: sessionId,
      blocking: request.arguments?['bloquea'] as bool? ?? false,
      external: !registrado.maintained,
    );
    if (result.error != null) return _text(result.error!);

    final requirement = result.requirement!;
    return _text(
      registrado.maintained
          ? 'Abrí ${requirement.code} hacia "${registrado.name}". Corre por su '
                'lado, en paralelo: seguí con lo tuyo y avisá qué queda '
                'esperando esto.'
          : 'Abrí ${requirement.code} hacia "${registrado.name}", que el '
                'usuario NO mantiene: queda anotado como externo y no lo va a '
                'tomar nadie automáticamente. Decilo en tu respuesta.',
    );
  }

  mcp.CallToolResult _take(mcp.CallToolRequest request) {
    final requirement = _byCode(request);
    if (requirement == null) return _text('No encontré ese requerimiento.');
    if (requirement.toProjectId != projectId) {
      return _text(
        'Ese requerimiento no te lo pidieron a vos: es de '
        '"${_nameOf(requirement.toProjectId)}".',
      );
    }
    final project = _project;
    if (project != null && !project.maintained) {
      return _text(
        'Este proyecto es de solo lectura: no toma requerimientos. Decilo en '
        'tu respuesta para que lo resuelva el usuario.',
      );
    }
    final error = _requirements.take(
      requirement.id,
      handle: _handle,
      sessionId: sessionId,
    );
    if (error != null) return _text(error);
    return _text(
      'Tomaste ${requirement.code}. Evaluá contra TU roadmap y dejá el '
      'veredicto con record_verdict antes de construir nada.',
    );
  }

  mcp.CallToolResult _verdict(mcp.CallToolRequest request) {
    final requirement = _byCode(request);
    if (requirement == null) return _text('No encontré ese requerimiento.');
    if (requirement.toProjectId != projectId) {
      return _text('El veredicto lo da el proyecto al que se lo pidieron.');
    }
    final error = _requirements.recordVerdict(
      requirement.id,
      handle: _handle,
      verdict: RequirementVerdict(
        kind: RequirementVerdictKind.fromAlias(
          (request.arguments?['veredicto'] as String? ?? '').trim(),
        ),
        reason: request.arguments?['razon'] as String? ?? '',
        prerequisites:
            (request.arguments?['antes_hay_que'] as List?)?.cast<String>() ??
            const [],
      ),
    );
    if (error != null) return _text(error);
    return _text('Anotado el veredicto de ${requirement.code}.');
  }

  mcp.CallToolResult _reply(mcp.CallToolRequest request) {
    final requirement = _byCode(request);
    if (requirement == null) return _text('No encontré ese requerimiento.');
    final side = _sideOf(requirement);
    if (side == null) return _text('Ese requerimiento no es de este proyecto.');

    final error = _requirements.reply(
      requirement.id,
      side: side,
      kind: side == RequirementSide.origen
          ? RequirementEntryKind.respuesta
          : RequirementEntryKind.avance,
      text: request.arguments?['texto'] as String? ?? '',
      handle: _handle,
    );
    if (error != null) return _text(error);
    return _text('Escrito en el hilo de ${requirement.code}.');
  }

  mcp.CallToolResult _requestClosure(mcp.CallToolRequest request) {
    final requirement = _byCode(request);
    if (requirement == null) return _text('No encontré ese requerimiento.');
    if (requirement.toProjectId != projectId) {
      return _text(
        'El cierre lo pide quien lo recibió. Vos lo abriste: si ya está, '
        'cerralo con close_requirement.',
      );
    }
    final error = _requirements.requestClosure(
      requirement.id,
      justification: request.arguments?['justificacion'] as String? ?? '',
      handle: _handle,
    );
    if (error != null) return _text(error);
    return _text(
      'Pediste el cierre de ${requirement.code}. Lo cierra quien lo abrió: '
      'no lo des por terminado hasta que lo haga.',
    );
  }

  mcp.CallToolResult _close(mcp.CallToolRequest request) {
    final requirement = _byCode(request);
    if (requirement == null) return _text('No encontré ese requerimiento.');

    // La asimetría, comprobada y no pedida: el proyecto sale de la URL, así
    // que un turno del destino no tiene cómo decir que es el origen.
    if (requirement.fromProjectId != projectId) {
      return _text(
        'Cerrar es de quien lo abrió, y ese es '
        '"${_nameOf(requirement.fromProjectId)}". Desde acá se PIDE el cierre '
        'con request_closure, justificando por qué ya está.',
      );
    }
    final error = _requirements.close(
      requirement.id,
      handle: _handle,
      note: request.arguments?['nota'] as String?,
    );
    if (error != null) return _text(error);
    return _text('Cerraste ${requirement.code}.');
  }

  // ── helpers ─────────────────────────────────────────────────────────

  InternalRequirement? _byCode(mcp.CallToolRequest request) {
    final code = (request.arguments?['codigo'] as String? ?? '').trim();
    return _requirements.byCode(
      code.toUpperCase().startsWith('REQ-') ? code : 'REQ-$code',
    );
  }

  RequirementSide? _sideOf(InternalRequirement requirement) {
    if (requirement.fromProjectId == projectId) return RequirementSide.origen;
    if (requirement.toProjectId == projectId) return RequirementSide.destino;
    return null;
  }

  mcp.CallToolResult _text(String message) =>
      mcp.CallToolResult(content: [mcp.TextContent(text: message)]);
}
