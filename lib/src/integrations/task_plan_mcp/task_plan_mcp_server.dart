import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dart_mcp/server.dart' as mcp;
import 'package:logger_rs/logger_rs.dart';
import 'package:stream_channel/stream_channel.dart';

import 'package:keel_ui/src/modules/stations/model/task_plan_item.dart';
import 'package:keel_ui/src/modules/stations/viewmodel/stations_viewmodel.dart';

/// Clave con la que se registra este servidor en la config MCP del turno.
const kTaskPlanMcpServerKey = 'keel-plan';
const kTaskPlanMcpToolPrefix = 'mcp__${kTaskPlanMcpServerKey}__';

/// Las dos tools que ve un miembro de estación durante su turno.
const kTaskPlanMcpToolNames = [
  '${kTaskPlanMcpToolPrefix}set_task_plan',
  '${kTaskPlanMcpToolPrefix}complete_plan_items',
];

/// Servidor MCP local que le da a los miembros de una estación el plan de
/// trabajo de SU tarea: escribirlo y marcar lo cumplido.
///
/// La ruta lleva estación, tarea y perfil, así que cada turno solo puede
/// tocar el plan de la tarea en la que está corriendo — no hace falta que el
/// modelo mande ids y no puede escribirle a otra tarea aunque quiera.
///
/// Una instancia nueva por cada POST, igual que `UserToolsMcpServer`: el CLI
/// corre el handshake dos veces por invocación y una instancia por request
/// nunca puede recibir un método repetido.
class TaskPlanMcpServer {
  TaskPlanMcpServer._();

  static HttpServer? _server;
  static String? _token;

  static Future<void> ensureStarted() async {
    if (_server != null) return;
    _token = _generateToken();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    unawaited(server.forEach(_handleRequest));
    Log.i('Task plan MCP server on 127.0.0.1:${server.port}');
  }

  /// La entrada de config para el turno de [profileId] en [taskId]. Null si
  /// el servidor todavía no levantó.
  static Map<String, dynamic>? mcpServerEntryFor({
    required String stationId,
    required String taskId,
    required String profileId,
  }) {
    final server = _server;
    final token = _token;
    if (server == null || token == null) return null;

    final uri = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: server.port,
      pathSegments: ['plan', stationId, taskId, profileId],
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
        segments[0] != 'plan') {
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
    _TaskPlanMcpServer(
      controller.foreign,
      stationId: segments[1],
      taskId: segments[2],
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
        'error': {'code': -32000, 'message': 'Task plan MCP server timed out'},
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

final class _TaskPlanMcpServer extends mcp.MCPServer with mcp.ToolsSupport {
  _TaskPlanMcpServer(
    super.channel, {
    required this.stationId,
    required this.taskId,
    required this.profileId,
    required bool willInitialize,
  }) : super.fromStreamChannel(
         implementation: mcp.Implementation(
           name: kTaskPlanMcpServerKey,
           version: '1.0.0',
         ),
         // La prosa de proceso (para qué es el plan, cuándo escribirlo) vive
         // en la sección PLAN del system prompt del turno; acá solo la
         // mecánica de la llamada, para no repetir la misma regla en dos
         // lugares que después divergen.
         instructions: 'El plan de trabajo de la tarea en la que estás.',
       ) {
    registerTool(_setPlanTool, _setPlan);
    registerTool(_completeTool, _complete);
    if (!willInitialize) {
      registerRequestHandler(mcp.ListToolsRequest.methodName, listTools);
      registerRequestHandler(mcp.CallToolRequest.methodName, callTool);
    }
  }

  final String stationId;
  final String taskId;
  final String profileId;

  StationsViewModel get _stations => StationsService.instance.notifier;

  static final _setPlanTool = mcp.Tool(
    name: 'set_task_plan',
    description:
        'Fija el plan de la tarea: reemplaza el anterior. Un punto cuyo '
        'texto no cambie conserva su estado de cumplido (la comparación '
        'ignora mayúsculas, acentos y puntuación). Cada item lleva `texto` '
        'y, opcionalmente, `puesto`.',
    inputSchema: mcp.ObjectSchema(
      properties: {
        'items': mcp.Schema.list(
          items: mcp.ObjectSchema(
            properties: {
              'texto': mcp.Schema.string(
                description: 'El punto, en una frase verificable.',
              ),
              'puesto': mcp.Schema.string(
                description:
                    'El ROL que lo tiene que hacer (implementador, revisor, '
                    'auditor…), igual que lo nombra un paso del workflow. '
                    'Nunca un @handle. Omitilo si todavía no está claro.',
              ),
            },
            required: ['texto'],
          ),
          description: 'Los puntos del plan, en orden.',
        ),
      },
      required: ['items'],
    ),
  );

  static final _completeTool = mcp.Tool(
    name: 'complete_plan_items',
    description:
        'Marca puntos del plan como cumplidos. Pasá el texto de cada punto '
        '(la comparación ignora mayúsculas, acentos y puntuación) o su id. '
        'Marcá solo lo que tu turno resolvió.',
    inputSchema: mcp.ObjectSchema(
      properties: {
        'items': mcp.Schema.list(
          items: mcp.Schema.string(),
          description: 'Texto o id de cada punto cumplido.',
        ),
      },
      required: ['items'],
    ),
  );

  Future<mcp.CallToolResult> _setPlan(mcp.CallToolRequest request) async {
    final items = _planEntries(request.arguments?['items']);
    if (items.isEmpty) {
      return _text('El plan tiene que tener al menos un punto.');
    }
    _stations.setTaskPlan(stationId, taskId, items);
    final asignados = items.where((entry) => entry.ownerRole != null).length;
    return _text(
      'Plan fijado: ${items.length} puntos, $asignados con puesto asignado.',
    );
  }

  /// Los puntos del plan. Acepta el objeto `{texto, puesto}` y también un
  /// string pelado: el modelo tiene los dos a la vista en el historial de la
  /// tarea, y rechazar el formato viejo convierte un acierto en un fallo.
  static List<PlanEntry> _planEntries(Object? value) {
    if (value is! List) return const [];
    final entries = <PlanEntry>[];
    for (final raw in value) {
      if (raw is String) {
        entries.add((text: raw, ownerRole: null));
        continue;
      }
      if (raw is! Map) continue;
      final text = raw['texto'] ?? raw['text'];
      if (text == null) continue;
      final owner = (raw['puesto'] ?? raw['rol'] ?? raw['ownerRole'])
          ?.toString()
          .trim();
      entries.add((
        text: text.toString(),
        ownerRole: owner == null || owner.isEmpty ? null : owner,
      ));
    }
    return entries;
  }

  Future<mcp.CallToolResult> _complete(mcp.CallToolRequest request) async {
    final items = _stringList(request.arguments?['items']);
    if (items.isEmpty) return _text('No me dijiste qué punto marcar.');

    final noEncontrados = _stations.completePlanItems(
      stationId,
      taskId,
      items: items,
      byProfileId: profileId,
    );
    final marcados = items.length - noEncontrados.length;
    final plan = _stations.planOf(stationId, taskId);

    return _text(
      noEncontrados.isEmpty
          ? 'Marqué $marcados. Van ${plan.doneCount} de ${plan.length}.'
          : 'Marqué $marcados. No encontré en el plan: '
                '${noEncontrados.join(' | ')}. Van ${plan.doneCount} de '
                '${plan.length} — copiá el texto del punto tal como figura '
                'en el plan (mayúsculas, acentos y puntuación no importan; '
                'las palabras sí).',
    );
  }

  static List<String> _stringList(Object? value) => value is List
      ? value.map((entry) => entry.toString()).toList()
      : const [];

  static mcp.CallToolResult _text(String message) =>
      mcp.CallToolResult(content: [mcp.TextContent(text: message)]);
}
