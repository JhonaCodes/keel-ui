library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dart_mcp/server.dart';
import 'package:logger_rs/logger_rs.dart';
import 'package:stream_channel/stream_channel.dart';

import 'package:keel_ui/src/integrations/mcp_catalog/mcp_catalog.dart';
import 'package:keel_ui/src/integrations/catalog_shape/catalog_shape.dart';
import 'package:keel_ui/src/integrations/assistant_mcp/keel_catalog_inspector.dart';
import 'package:keel_ui/src/modules/hooks/model/hook.dart';
import 'package:keel_ui/src/modules/catalog_locks/model/catalog_lock.dart';
import 'package:keel_ui/src/modules/catalog_locks/viewmodel/catalog_locks_viewmodel.dart';
import 'package:keel_ui/src/modules/hooks/model/hook_event.dart';
import 'package:keel_ui/src/modules/hooks/viewmodel/hooks_viewmodel.dart';
import 'package:keel_ui/src/integrations/system_vault/system_vault.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/boards/viewmodel/boards_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/model/permission_request.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/session_message_reference.dart';
import 'package:keel_ui/src/modules/projects/model/session_reply_request.dart';
import 'package:keel_ui/src/modules/knowledge/model/knowledge_base.dart';
import 'package:keel_ui/src/modules/knowledge/viewmodel/knowledge_viewmodel.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';
import 'package:keel_ui/src/modules/assistant/model/assistant_action.dart';
import 'package:keel_ui/src/modules/assistant/service/assistant_action_executor.dart';
import 'package:keel_ui/src/modules/mcp_servers/model/mcp_server_config.dart';
import 'package:keel_ui/src/modules/mcp_servers/viewmodel/mcp_servers_viewmodel.dart';
import 'package:keel_ui/src/modules/rules/viewmodel/rules_viewmodel.dart';
import 'package:keel_ui/src/modules/secrets/viewmodel/secrets_viewmodel.dart';
import 'package:keel_ui/src/modules/settings/viewmodel/settings_viewmodel.dart';
// Solo el enum: `Tool` acá es la definición MCP de `dart_mcp`, no el modelo
// de tool ejecutable del proyecto.
import 'package:keel_ui/src/modules/tools/model/tool.dart' show ToolRuntime;
import 'package:keel_ui/src/modules/skills/viewmodel/skills_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/requirements/viewmodel/requirements_viewmodel.dart';
import 'package:keel_ui/src/modules/tools/viewmodel/tools_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/service/workflow_deletion_service.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';
import 'package:keel_ui/src/integrations/system_prompt/system_prompt.dart';
import 'package:keel_ui/src/modules/projects/service/node_context.dart';
import 'package:keel_ui/src/modules/projects/model/turn_outcome_report.dart';

part 'src/tool_definitions.dart';
part 'src/tool_handlers.dart';
part 'src/keelai_mcp_server_impl.dart';

/// Tool names as they surface to `claude --allowedTools`: the MCP spec
/// prefixes every tool with `mcp__<server-key>__`, where the server key is
/// whatever name a `--mcp-config` entry gives it — see [mcpConfigFor].
const kKeelAiMcpToolNames = [
  'mcp__keelai-actions__create_skill',
  'mcp__keelai-actions__create_rule',
  'mcp__keelai-actions__create_tool',
  'mcp__keelai-actions__request_secret',
  'mcp__keelai-actions__list_catalog',
  'mcp__keelai-actions__list_workflows',
  'mcp__keelai-actions__list_projects',
  'mcp__keelai-actions__get_item',
  'mcp__keelai-actions__list_locked_items',
  'mcp__keelai-actions__lock_item',
  'mcp__keelai-actions__unlock_item',
  'mcp__keelai-actions__describe_system',
  'mcp__keelai-actions__list_secret_names',
  'mcp__keelai-actions__update_skill',
  'mcp__keelai-actions__update_rule',
  'mcp__keelai-actions__update_tool',
  'mcp__keelai-actions__update_workflow',
  'mcp__keelai-actions__unassign_from_agent',
  'mcp__keelai-actions__update_project',
  'mcp__keelai-actions__open_project_session',
  'mcp__keelai-actions__list_project_sessions',
  'mcp__keelai-actions__read_session_thread',
  'mcp__keelai-actions__resolve_message_reference',
  'mcp__keelai-actions__reply_in_session',
  'mcp__keelai-actions__inspect_session',
  'mcp__keelai-actions__intervene',
  'mcp__keelai-actions__answer_decision',
  'mcp__keelai-actions__lint_workflow',
  'mcp__keelai-actions__register_mcp_server',
  'mcp__keelai-actions__list_mcp_catalog',
  'mcp__keelai-actions__install_mcp_integration',
  'mcp__keelai-actions__delete_mcp_server',
  'mcp__keelai-actions__create_hook',
  'mcp__keelai-actions__set_hook_enabled',
  'mcp__keelai-actions__delete_hook',
  'mcp__keelai-actions__backup_system',
  'mcp__keelai-actions__restore_system',
  'mcp__keelai-actions__sync_knowledge',
  'mcp__keelai-actions__create_knowledge_base',
  'mcp__keelai-actions__update_knowledge_base',
  'mcp__keelai-actions__delete_knowledge_base',
  'mcp__keelai-actions__create_or_update_agent',
  'mcp__keelai-actions__create_workflow',
  'mcp__keelai-actions__create_project',
  'mcp__keelai-actions__delete_skill',
  'mcp__keelai-actions__delete_rule',
  'mcp__keelai-actions__delete_tool',
  'mcp__keelai-actions__delete_agent',
  'mcp__keelai-actions__delete_workflow',
  'mcp__keelai-actions__delete_project',
];

/// Local MCP server exposing Keel AI's create/update tools over HTTP on
/// loopback. Runs in-process — tool handlers call the very same ViewModels
/// the rest of the app uses, so there's no IPC and no second writer to
/// `flutter_local_db`.
///
/// A fresh [KeelAiMcpServer] is created for every incoming HTTP POST and
/// discarded right after it answers — see [_handleRequest]. This is
/// deliberate: the real `claude` CLI runs the full MCP handshake
/// (`server/discover → initialize → notifications/initialized →
/// tools/list`) TWICE per invocation (confirmed by tracing the actual
/// protocol), and reusing one long-lived server instance across that would
/// hit `dart_mcp`'s own guard against calling `initialize` twice on an
/// already-initialized instance. A fresh instance per request never
/// receives a method more than once, so that guard can never fire, and no
/// cross-request session state is needed since every tool handler resolves
/// what it needs (the target `agentId`) from the URL path each time.
class AssistantMcpServer {
  AssistantMcpServer._();

  static HttpServer? _server;
  static String? _token;

  /// Starts the server once. Safe to call more than once — only the first
  /// call does anything, so `main()` can call it unconditionally.
  static Future<void> start() async {
    if (_server != null) return;

    _token = _generateToken();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    Log.i('Keel AI MCP server listening on 127.0.0.1:${server.port}');

    server.listen((request) async {
      try {
        await _handleRequest(request);
      } catch (error, stackTrace) {
        Log.e(
          'Keel AI MCP server request failed',
          error: error,
          stackTrace: stackTrace,
        );
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      }
    });
  }

  /// The `mcpServers` config entry (key `keelai-actions`) for [agentId]'s
  /// turn, or null before [start] has run. Returned as an entry rather than
  /// a whole `--mcp-config` JSON so the caller can combine it with other
  /// local servers (e.g. the user-tools one) in a single config. [agentId]
  /// travels in the URL path (not a header) so each tool call can be
  /// attributed to the exact conversation it belongs to.
  static Map<String, dynamic>? mcpServerEntryFor(String agentId) {
    final server = _server;
    final token = _token;
    if (server == null || token == null) return null;

    return {
      'type': 'http',
      'url': 'http://127.0.0.1:${server.port}/mcp/$agentId',
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
    final agentId = segments[1];

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

    if (method != InitializeRequest.methodName &&
        method != ListToolsRequest.methodName &&
        method != CallToolRequest.methodName) {
      // Covers the CLI's undocumented `server/discover` probe (sent before
      // `initialize`) and anything else unimplemented — a real JSON-RPC
      // "method not found", which the CLI tolerates and moves past, rather
      // than a hang or a dropped connection.
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
    KeelAiMcpServer(
      controller.foreign,
      agentId: agentId,
      willInitialize: method == InitializeRequest.methodName,
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

    // `tools/call` NO tiene plazo, y es a propósito: adentro puede estar
    // esperándote a vos. Un permiso sobre un elemento bloqueado suspende la
    // tool hasta que contestás, y cortar acá a los treinta segundos era lo
    // que rompía el flujo entero — el modelo recibía «la tool falló»
    // mientras la tarjeta seguía en pantalla, y tu aprobación llegaba a un
    // teléfono descolgado: la escritura se hacía y nadie la escuchaba.
    //
    // Lo que termina esta espera no es un reloj sino el turno: al detenerlo,
    // el permiso se cancela y el completer se resuelve. Ver
    // `AgentsViewModel.requestCatalogChangePermission`.
    //
    // El resto de los métodos sí tiene corte: `initialize` y `tools/list`
    // contestan con lo que ya está en memoria, y uno que no vuelve en diez
    // segundos está roto, no ocupado.
    final isToolCall = method == CallToolRequest.methodName;
    final reply = isToolCall
        ? await replyCompleter.future
        : await replyCompleter.future.timeout(
            const Duration(seconds: 10),
            onTimeout: () => jsonEncode({
              'jsonrpc': '2.0',
              'id': id,
              'error': {
                'code': -32000,
                'message': 'Keel AI MCP server timed out',
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
