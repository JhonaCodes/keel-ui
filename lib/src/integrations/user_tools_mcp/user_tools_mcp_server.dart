library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dart_mcp/server.dart' as mcp;
import 'package:logger_rs/logger_rs.dart';
import 'package:stream_channel/stream_channel.dart';

import 'package:keel_ui/src/core/services/tool_execution_service.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/secrets/viewmodel/secrets_viewmodel.dart';
import 'package:keel_ui/src/modules/tools/model/tool.dart';
import 'package:keel_ui/src/modules/tools/viewmodel/tools_viewmodel.dart';
import 'package:keel_ui/src/integrations/system_prompt/system_prompt.dart';

/// How a registered [Tool]'s name surfaces to `claude --allowedTools`: the
/// MCP spec prefixes every tool with `mcp__<server-key>__`, and the server
/// key is what [UserToolsMcpServer.mcpServerEntryFor]'s config entry is
/// registered under — `keel-tools`.
const kUserToolsMcpServerKey = 'keel-tools';
const kUserToolsMcpToolPrefix = 'mcp__${kUserToolsMcpServerKey}__';

/// Local MCP server exposing the user-registered deterministic tools to any
/// agent whose profile has them assigned. Runs in-process on loopback HTTP —
/// reachable from the CLI subprocess of a 1:1 chat AND from the one a
/// project turn spawns inside its worker isolate, since both are plain
/// processes talking to 127.0.0.1.
///
/// A fresh [_UserToolsMcpServer] is created for every incoming HTTP POST and
/// discarded right after it answers — same reasoning as
/// `AssistantMcpServer`: the real `claude` CLI runs the MCP handshake twice
/// per invocation, and a per-request instance can never receive a method
/// twice, so `dart_mcp`'s double-initialize guard can never fire. The URL
/// path carries the PROFILE id (tools are assigned to profiles, not to live
/// agents), plus the turn's working directory as a query parameter so a
/// script sees the same cwd as the agent that called it.
class UserToolsMcpServer {
  UserToolsMcpServer._();

  static HttpServer? _server;
  static String? _token;

  /// Starts the server once. Safe to call more than once — only the first
  /// call does anything, so `main()` can call it unconditionally.
  static Future<void> start() async {
    if (_server != null) return;

    _token = _generateToken();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    Log.i('User tools MCP server listening on 127.0.0.1:${server.port}');

    server.listen((request) async {
      try {
        await _handleRequest(request);
      } catch (error, stackTrace) {
        Log.e(
          'User tools MCP server request failed',
          error: error,
          stackTrace: stackTrace,
        );
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      }
    });
  }

  /// The `mcpServers` config entry for [profileId]'s turn, or null before
  /// [start] has run. [workingDirectory] is where that turn's scripts run,
  /// so relative paths passed as arguments resolve exactly like they would
  /// for the agent itself.
  static Map<String, dynamic>? mcpServerEntryFor(
    String profileId, {
    required String workingDirectory,
  }) {
    final server = _server;
    final token = _token;
    if (server == null || token == null) return null;

    final uri = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: server.port,
      pathSegments: ['mcp', profileId],
      queryParameters: {'cwd': workingDirectory},
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
        segments.length != 2 ||
        segments[0] != 'mcp') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final profileId = segments[1];
    final workingDirectory =
        request.uri.queryParameters['cwd'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;

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
      // A notification (e.g. `notifications/initialized`) — nothing in this
      // one-shot-per-request design needs to observe it, and the protocol
      // expects no response body for one.
      request.response.statusCode = HttpStatus.accepted;
      await request.response.close();
      return;
    }

    if (method != mcp.InitializeRequest.methodName &&
        method != mcp.ListToolsRequest.methodName &&
        method != mcp.CallToolRequest.methodName) {
      // Covers the CLI's undocumented `server/discover` probe and anything
      // else unimplemented — a real JSON-RPC "method not found", which the
      // CLI tolerates and moves past, rather than a hang.
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
    _UserToolsMcpServer(
      controller.foreign,
      profileId: profileId,
      workingDirectory: workingDirectory,
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

    // Generous on purpose: a `tools/call` legitimately runs a script that
    // may take up to its own timeout, so the HTTP reply must outwait it.
    final reply = await replyCompleter.future.timeout(
      const Duration(seconds: kMaxToolTimeoutSeconds + 30),
      onTimeout: () => jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'error': {'code': -32000, 'message': 'User tools MCP server timed out'},
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

/// One instance per incoming HTTP POST — see
/// [UserToolsMcpServer._handleRequest]. The registered tool list is resolved
/// fresh from the profile + tools catalogs on every request, so a tool
/// created or reassigned mid-conversation is already there on the model's
/// next `tools/list` without restarting anything.
///
/// [willInitialize] must be true only when the incoming message's method is
/// literally `initialize` — same duplicate-handler reasoning as
/// `KeelAiMcpServer`.
final class _UserToolsMcpServer extends mcp.MCPServer with mcp.ToolsSupport {
  _UserToolsMcpServer(
    super.channel, {
    required String profileId,
    required String workingDirectory,
    required bool willInitialize,
  }) : super.fromStreamChannel(
         implementation: mcp.Implementation(
           name: kUserToolsMcpServerKey,
           version: '1.0.0',
         ),
         instructions: kUserToolsMcpInstructions,
       ) {
    for (final tool in _assignedTools(profileId)) {
      registerTool(
        _mcpToolFor(tool),
        (request) => _dispatch(tool, request, workingDirectory),
      );
    }
    if (!willInitialize) {
      registerRequestHandler(mcp.ListToolsRequest.methodName, listTools);
      registerRequestHandler(mcp.CallToolRequest.methodName, callTool);
    }
  }

  static List<Tool> _assignedTools(String profileId) {
    final profile = AgentProfilesService.instance.notifier.data.profiles
        .where((profile) => profile.id == profileId)
        .firstOrNull;
    if (profile == null) return const [];
    return ToolsService.instance.notifier.toolsByNames(profile.tools);
  }

  static mcp.Tool _mcpToolFor(Tool tool) {
    return mcp.Tool(
      name: tool.name,
      description:
          '${tool.description}\n\n'
          'Script ${tool.runtime.label} determinista — usala en lugar de '
          'hacer ese trabajo a mano. Los argumentos van como argv '
          'posicionales; preferí rutas absolutas.',
      inputSchema: mcp.ObjectSchema(
        properties: {
          'args': mcp.Schema.list(
            items: mcp.Schema.string(),
            description:
                'Argumentos posicionales que recibe el script (argv), en '
                'orden. Vacío si no necesita ninguno.',
          ),
        },
      ),
    );
  }

  static Future<mcp.CallToolResult> _dispatch(
    Tool tool,
    mcp.CallToolRequest request,
    String workingDirectory,
  ) async {
    final args =
        ((request.arguments ?? const {})['args'] as List?)?.cast<String>() ??
        const <String>[];

    // Declared-but-unfilled secrets fail CLOSED with an actionable message —
    // running anyway would hand the script a hole where a credential should
    // be, and the model can't fix that; only the user can.
    final secrets = SecretsService.instance.notifier;
    final pending = secrets.pendingOf(tool.secretNames);
    if (pending.isNotEmpty) {
      return mcp.CallToolResult(
        content: [
          mcp.TextContent(
            text: jsonEncode({
              'ok': false,
              'error':
                  'Secrets pendientes de valor: ${pending.join(', ')}. '
                  'El usuario debe cargarlos en la pantalla de Secrets '
                  'antes de poder ejecutar esta tool.',
            }),
          ),
        ],
        isError: true,
      );
    }

    final result = await ToolExecutionService().run(
      tool,
      args: args,
      workingDirectory: workingDirectory,
      environment: secrets.valuesFor(tool.secretNames),
    );
    return mcp.CallToolResult(
      content: [mcp.TextContent(text: jsonEncode(result.toJson()))],
      isError: !result.ok,
    );
  }
}
