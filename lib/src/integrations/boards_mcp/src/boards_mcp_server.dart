part of '../boards_mcp.dart';

const kBoardsMcpServerKey = 'keel-boards';
const kBoardsMcpToolPrefix = 'mcp__${kBoardsMcpServerKey}__';

/// Lo que ve un miembro de proyecto para armarle tableros de prueba.
const kBoardsMcpToolNames = [
  '${kBoardsMcpToolPrefix}list_boards',
  '${kBoardsMcpToolPrefix}get_board',
  '${kBoardsMcpToolPrefix}create_board',
  '${kBoardsMcpToolPrefix}update_board',
  '${kBoardsMcpToolPrefix}delete_board',
];

/// La forma de la especificación, escrita una vez y usada en las dos tools
/// que la reciben. Es lo primero que lee el modelo, así que dice el
/// vocabulario entero.
const _specDescription = '''
La especificación del tablero:
{
  "name": "Lanzar oferta",
  "note": "para qué sirve y contra qué ambiente",
  "fields": [
    {"key": "producto", "label": "Producto", "default": "SKU-1183"},
    {"key": "cantidad", "kind": "numero", "default": "40"},
    {"key": "ambiente", "kind": "opcion", "options": ["dev", "staging"]},
    {"key": "token", "kind": "secreto", "secret_name": "TOKEN_BUYER_DEV"}
  ],
  "actions": [{
    "label": "Lanzar",
    "steps": [{
      "kind": "http", "method": "POST",
      "url": "https://{{ambiente}}.api/v1/offers",
      "headers": {"Authorization": "Bearer {{token}}"},
      "body": "{\\"sku\\": \\"{{producto}}\\", \\"qty\\": {{cantidad}}}"
    }]
  }]
}
kind de campo: texto | multilinea | numero | booleano | opcion | json | secreto.
kind de paso: http (method, url, headers, body) | comando (command, args).
Un paso puede guardar algo para el siguiente con "captures":
  [{"as": "token", "from": "salida"}]                  la salida del comando
  [{"as": "id", "from": "json", "path": "data.id"}]    del cuerpo JSON
  [{"as": "s", "from": "header", "path": "X-Id"}]      de un header
Toda {{clave}} tiene que ser un campo del tablero o algo que capturó un paso
ANTERIOR, o la tool falla diciendo cuál falta.''';

/// Servidor MCP local con los tableros de este proyecto.
class BoardsMcpServer {
  BoardsMcpServer._();

  static HttpServer? _server;
  static String? _token;

  static Future<void> ensureStarted() async {
    if (_server != null) return;
    _token = _generateToken();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    unawaited(server.forEach(_handleRequest));
    Log.i('Boards MCP server on 127.0.0.1:${server.port}');
  }

  static Map<String, dynamic>? mcpServerEntryFor({
    required String projectId,
    required String sessionId,
    required String profileId,
  }) {
    final server = _server;
    final token = _token;
    if (server == null || token == null) return null;

    final uri = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: server.port,
      pathSegments: ['boards', projectId, sessionId, profileId],
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
        segments[0] != 'boards') {
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
    _BoardsMcpServer(
      controller.foreign,
      projectId: segments[1],
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
        'error': {'code': -32000, 'message': 'Boards MCP server timed out'},
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

final class _BoardsMcpServer extends mcp.MCPServer with mcp.ToolsSupport {
  _BoardsMcpServer(
    super.channel, {
    required this.projectId,
    required this.profileId,
    required bool willInitialize,
  }) : super.fromStreamChannel(
         implementation: mcp.Implementation(
           name: kBoardsMcpServerKey,
           version: '1.0.0',
         ),
         instructions:
             'Los tableros de prueba de este proyecto: pantallitas para que '
             'el usuario dispare algo contra su propia app. Vos los ARMÁS; '
             'dispararlos es de él, y por eso no hay tool para correrlos.',
       ) {
    registerTool(_listTool, _list);
    registerTool(_getTool, _get);
    registerTool(_createTool, _create);
    registerTool(_updateTool, _update);
    registerTool(_deleteTool, _delete);
    if (!willInitialize) {
      registerRequestHandler(mcp.ListToolsRequest.methodName, listTools);
      registerRequestHandler(mcp.CallToolRequest.methodName, callTool);
    }
  }

  final String projectId;
  final String profileId;

  BoardsViewModel get _boards => BoardsService.instance.notifier;

  // ── tools ───────────────────────────────────────────────────────────

  static final _listTool = mcp.Tool(
    name: 'list_boards',
    description:
        'Los tableros que ya tiene este proyecto, con sus campos y sus '
        'acciones. Miralo antes de crear uno: puede que ya exista y haya que '
        'actualizarlo.',
    inputSchema: mcp.ObjectSchema(properties: {}),
  );

  static final _getTool = mcp.Tool(
    name: 'get_board',
    description: 'La especificación completa de un tablero, para corregirla.',
    inputSchema: mcp.ObjectSchema(
      properties: {'nombre': mcp.Schema.string()},
      required: ['nombre'],
    ),
  );

  static final _createTool = mcp.Tool(
    name: 'create_board',
    description:
        'Crea un tablero de prueba en este proyecto: una pantallita con '
        'campos y botones para que el usuario dispare algo contra su propia '
        'API (lanzar una oferta, mandar un push, pegarle a un endpoint '
        'nuevo). Leé el código o el OpenAPI primero para que los campos y el '
        'cuerpo sean los de verdad. Idempotente por nombre.\n\n$_specDescription',
    inputSchema: mcp.ObjectSchema(
      properties: {
        'spec': mcp.ObjectSchema(
          properties: {},
          description: 'El objeto de la especificación.',
        ),
      },
      required: ['spec'],
    ),
  );

  static final _updateTool = mcp.Tool(
    name: 'update_board',
    description:
        'Reemplaza la especificación de un tablero que ya existe. Manda la '
        'especificación ENTERA: lo que no venga, no queda.\n\n$_specDescription',
    inputSchema: mcp.ObjectSchema(
      properties: {
        'nombre': mcp.Schema.string(description: 'El tablero a reemplazar.'),
        'spec': mcp.ObjectSchema(properties: {}),
      },
      required: ['nombre', 'spec'],
    ),
  );

  static final _deleteTool = mcp.Tool(
    name: 'delete_board',
    description: 'Elimina un tablero de este proyecto, y sus corridas.',
    inputSchema: mcp.ObjectSchema(
      properties: {'nombre': mcp.Schema.string()},
      required: ['nombre'],
    ),
  );

  // ── handlers ────────────────────────────────────────────────────────

  mcp.CallToolResult _list(mcp.CallToolRequest request) {
    final boards = _boards.data.forProject(projectId);
    if (boards.isEmpty) {
      return _text('Este proyecto todavía no tiene tableros.');
    }
    return _text(
      jsonEncode([
        for (final board in boards)
          {
            'nombre': board.name,
            'note': board.note,
            'campos': [for (final field in board.fields) field.key],
            'acciones': [
              for (final action in board.actions)
                {
                  'label': action.label,
                  'pasos': [for (final step in action.steps) step.preview],
                },
            ],
          },
      ]),
    );
  }

  mcp.CallToolResult _get(mcp.CallToolRequest request) {
    final board = _named(request);
    if (board == null) return _text(_notFound(request));
    return _text(jsonEncode(board.toJson()));
  }

  mcp.CallToolResult _create(mcp.CallToolRequest request) =>
      _save(request, existing: null);

  mcp.CallToolResult _update(mcp.CallToolRequest request) {
    final board = _named(request);
    if (board == null) return _text(_notFound(request));
    return _save(request, existing: board);
  }

  /// El único camino por el que un tablero entra al sistema. Todo lo que
  /// escribe el modelo pasa por [parseBoardSpec] antes de existir.
  mcp.CallToolResult _save(
    mcp.CallToolRequest request, {
    required Board? existing,
  }) {
    if (ProjectsService.instance.notifier.data.projects
            .where((project) => project.id == projectId)
            .firstOrNull ==
        null) {
      return _text('Este proyecto ya no existe.');
    }

    final raw = request.arguments?['spec'];
    if (raw is! Map) {
      return _text('Falta "spec", el objeto con la especificación.');
    }

    final result = parseBoardSpec(
      raw.cast<String, dynamic>(),
      projectId: projectId,
      createdByProfileId: profileId,
      existing: existing ?? _boards.boardNamed(projectId, _nameIn(raw)),
    );
    if (result.board == null) {
      return _text(
        'No pude crear el tablero:\n- ${result.errors.join('\n- ')}',
      );
    }

    final board = result.board!;
    _boards.upsert(board);
    return _text(
      '${existing == null ? "Creé" : "Actualicé"} el tablero '
      '"${board.name}" (${board.fields.length} campos, '
      '${board.actions.length} acciones). Está en el sidebar del proyecto, '
      'debajo de Estado. Dispararlo es del usuario: no hay tool para '
      'correrlo, así que si querés que lo pruebe, pedíselo.',
    );
  }

  mcp.CallToolResult _delete(mcp.CallToolRequest request) {
    final board = _named(request);
    if (board == null) return _text(_notFound(request));
    _boards.deleteBoard(board.id);
    return _text('Eliminé el tablero "${board.name}".');
  }

  // ── helpers ─────────────────────────────────────────────────────────

  String _nameIn(Map raw) => (raw['name'] as String? ?? '').trim();

  Board? _named(mcp.CallToolRequest request) {
    final name = (request.arguments?['nombre'] as String? ?? '').trim();
    return _boards.boardNamed(projectId, name);
  }

  String _notFound(mcp.CallToolRequest request) {
    final existing = _boards.data
        .forProject(projectId)
        .map((board) => board.name)
        .toList();
    final sugerencia = existing.isEmpty
        ? 'Este proyecto no tiene ninguno.'
        : 'Los que hay: ${existing.join(', ')}.';
    return 'No encontré ese tablero. $sugerencia';
  }

  mcp.CallToolResult _text(String message) =>
      mcp.CallToolResult(content: [mcp.TextContent(text: message)]);
}
