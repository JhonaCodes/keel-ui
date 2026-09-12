import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dart_mcp/server.dart' as mcp;
import 'package:logger_rs/logger_rs.dart';
import 'package:stream_channel/stream_channel.dart';

import 'package:keel_ui/src/integrations/hook_delivery/hook_delivery.dart';
import 'package:keel_ui/src/integrations/system_prompt/system_prompt.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';

/// Clave con la que se registra el servidor MCP de decisiones en la config
/// del turno.
const kDecisionsMcpServerKey = 'keel-decisions';
const kDecisionsMcpToolPrefix = 'mcp__${kDecisionsMcpServerKey}__';

/// La única tool que ve el agente: preguntarle algo a la persona y ESPERAR.
const kDecisionsMcpToolNames = ['${kDecisionsMcpToolPrefix}ask_user'];

/// El servidor loopback que suspende un turno hasta que la persona decide.
///
/// Dos entradas sobre el mismo proceso y el mismo token:
///
/// - `POST /gate/{proyecto}/{sesión}/{perfil}`: la llama el hook
///   `keel-decision-gate` antes de cada tool que escribe, con
///   `{tool_name, tool_input}`, y se queda esperando la respuesta
///   `{decision: allow|deny, reason}`. Es HTTP pelado porque quien pregunta
///   es un script, no un cliente MCP.
/// - `POST /ask/{proyecto}/{sesión}/{perfil}`: un MCP con la tool
///   `ask_user`, para que el agente pregunte y siga en el mismo turno en vez
///   de cerrarlo con `needs_user`.
///
/// Ninguna de las dos tiene plazo del lado del servidor: esperar a una
/// persona no tiene plazo. El plazo lo pone el vigilante del turno, que se
/// pausa mientras hay una decisión pendiente.
class DecisionGateServer {
  DecisionGateServer._();

  static HttpServer? _server;
  static String? _token;

  static Future<void> ensureStarted() async {
    if (_server != null) return;
    _token = _generateToken();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    unawaited(server.forEach(_handleRequest));
    Log.i('Decision gate server on 127.0.0.1:${server.port}');
  }

  static DecisionGateSpec? gateSpecFor({
    required String projectId,
    required String sessionId,
    required String profileId,
  }) {
    final server = _server;
    final token = _token;
    if (server == null || token == null) return null;
    return DecisionGateSpec(
      url: _uri(server, ['gate', projectId, sessionId, profileId]).toString(),
      token: token,
    );
  }

  static Map<String, dynamic>? mcpServerEntryFor({
    required String projectId,
    required String sessionId,
    required String profileId,
  }) {
    final server = _server;
    final token = _token;
    if (server == null || token == null) return null;
    return {
      'type': 'http',
      'url': _uri(server, ['ask', projectId, sessionId, profileId]).toString(),
      'headers': {'Authorization': 'Bearer $token'},
    };
  }

  static Uri _uri(HttpServer server, List<String> segments) => Uri(
    scheme: 'http',
    host: '127.0.0.1',
    port: server.port,
    pathSegments: segments,
  );

  static Future<void> _handleRequest(HttpRequest request) async {
    final token = _token;
    if (token == null ||
        request.headers.value('authorization') != 'Bearer $token') {
      request.response.statusCode = HttpStatus.unauthorized;
      await request.response.close();
      return;
    }
    final segments = request.uri.pathSegments;
    if (request.method != 'POST' || segments.length != 4) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    switch (segments[0]) {
      case 'gate':
        await _handleGate(request, segments);
      case 'ask':
        await _handleAsk(request, segments);
      default:
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
    }
  }

  static Future<void> _handleGate(
    HttpRequest request,
    List<String> segments,
  ) async {
    final body = await utf8.decoder.bind(request).join();
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }
    final toolName = (payload['tool_name'] ?? '').toString();
    final decision = await ProjectsService.instance.notifier.decideToolUse(
      projectId: segments[1],
      sessionId: segments[2],
      profileId: segments[3],
      toolName: toolName,
      toolInput: describeToolInput(toolName, payload['tool_input']),
    );
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'decision': decision.allow ? 'allow' : 'deny',
        'reason': decision.reason,
      }),
    );
    await request.response.close();
  }

  static Future<void> _handleAsk(
    HttpRequest request,
    List<String> segments,
  ) async {
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
    _DecisionsMcpServer(
      controller.foreign,
      projectId: segments[1],
      sessionId: segments[2],
      profileId: segments[3],
      willInitialize: method == mcp.InitializeRequest.methodName,
    );
    final reply = Completer<String>();
    controller.local.stream.listen(
      (data) {
        if (!reply.isCompleted) reply.complete(data);
      },
      onError: (Object error) {
        if (!reply.isCompleted) reply.completeError(error);
      },
    );
    controller.local.sink.add(jsonEncode(message));

    // Sin plazo para `tools/call`: adentro hay una persona pensando. El
    // handshake sí tiene uno, corto, por si el cliente se fue.
    final answer = method == mcp.CallToolRequest.methodName
        ? await reply.future
        : await reply.future.timeout(
            const Duration(seconds: 10),
            onTimeout: () => jsonEncode({
              'jsonrpc': '2.0',
              'id': id,
              'error': {'code': -32000, 'message': 'Decisions MCP timed out'},
            }),
          );
    await controller.local.sink.close();
    request.response.headers.contentType = ContentType.json;
    request.response.write(answer);
    await request.response.close();
  }

  /// Lo que se le muestra a la persona de la tool: el comando de un Bash, la
  /// ruta de una escritura, y para el resto el JSON recortado.
  static String describeToolInput(String toolName, Object? input) {
    if (input is Map) {
      final command = input['command'];
      if (command is String && command.isNotEmpty) return _clip(command);
      final path = input['file_path'] ?? input['path'] ?? input['notebook_path'];
      if (path is String && path.isNotEmpty) return _clip(path);
    }
    if (input == null) return '';
    return _clip(input is String ? input : jsonEncode(input));
  }

  static String _clip(String text) =>
      text.length <= 300 ? text : '${text.substring(0, 300)}…';

  static String _generateToken() {
    final random = Random.secure();
    return List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

final class _DecisionsMcpServer extends mcp.MCPServer with mcp.ToolsSupport {
  _DecisionsMcpServer(
    super.channel, {
    required this.projectId,
    required this.sessionId,
    required this.profileId,
    required bool willInitialize,
  }) : super.fromStreamChannel(
         implementation: mcp.Implementation(
           name: kDecisionsMcpServerKey,
           version: '1.0.0',
         ),
         instructions: kDecisionsMcpInstructions,
       ) {
    registerTool(_askTool, _ask);
    if (!willInitialize) {
      registerRequestHandler(mcp.ListToolsRequest.methodName, listTools);
      registerRequestHandler(mcp.CallToolRequest.methodName, callTool);
    }
  }

  final String projectId;
  final String sessionId;
  final String profileId;

  static final _askTool = mcp.Tool(
    name: 'ask_user',
    description:
        'Solicita una decisión o un dato que solo el usuario tiene. La primera '
        'llamada del turno puede devolver CONTEXTO RECUPERADO POR KEEL: revisa '
        'el pedido, encargo y avance; esto NO es una respuesta del usuario. '
        'Si resuelve la duda, continúa trabajando. Si falta una decisión real, '
        'vuelve a llamar con la pregunta concreta y entonces se mostrará al '
        'usuario. No selecciones otra tarea por haber perdido el contexto. '
        '`options` es opcional: incluye alternativas claras cuando existan.',
    inputSchema: mcp.ObjectSchema(
      properties: {
        'question': mcp.Schema.string(
          description: 'La pregunta, concreta y con el contexto justo.',
        ),
        'options': mcp.Schema.list(
          items: mcp.Schema.string(),
          description: 'Respuestas posibles, si las hay.',
        ),
      },
      required: ['question'],
    ),
  );

  Future<mcp.CallToolResult> _ask(mcp.CallToolRequest request) async {
    final question = (request.arguments?['question'] ?? '').toString().trim();
    if (question.isEmpty) {
      return _text('La pregunta está vacía.');
    }
    final options = switch (request.arguments?['options']) {
      final List list => [for (final entry in list) entry.toString()],
      _ => const <String>[],
    };
    final answer = await ProjectsService.instance.notifier.askUser(
      projectId: projectId,
      sessionId: sessionId,
      profileId: profileId,
      question: question,
      options: options,
    );
    return _text(answer);
  }

  static mcp.CallToolResult _text(String message) =>
      mcp.CallToolResult(content: [mcp.TextContent(text: message)]);
}
