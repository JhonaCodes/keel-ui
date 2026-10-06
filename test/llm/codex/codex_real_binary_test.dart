import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_core/integrations/hook_delivery/hook_delivery.dart';
import 'package:keel_core/integrations/llm/codex/codex_cli_runner.dart';
import 'package:keel_core/integrations/llm/llm.dart';
import 'package:keel_core/modules/hooks/model/hook_event.dart';

/// Runs the REAL `codex` binary against a fake model provider and a fake MCP
/// server, both in this process. No account, no network beyond loopback:
/// test/run_codex_real_binary.sh points CODEX_HOME at a temp dir whose
/// config.toml makes `keel_fake` the model provider.
void main() {
  final enabled = Platform.environment['KEEL_REAL_CODEX'] == '1';

  test(
    'codex runs a Keel MCP tool instead of rejecting it for approval',
    () async {
      final codexHome = Platform.environment['CODEX_HOME'] ?? '';
      final realHome = '${Platform.environment['HOME']}/.codex';
      expect(codexHome, isNotEmpty);
      expect(codexHome, isNot(realHome));

      final mcp = _FakeMcpServer();
      await mcp.start();
      addTearDown(mcp.close);
      final model = _FakeModelProvider(toolSuffix: 'ping');
      await model.start();
      addTearDown(model.close);

      // An unknown slug keeps MCP tools as plain namespaced functions; real
      // slugs may route them through codex's code mode instead.
      _useFakeProvider(codexHome, model.port, model: 'fake-model');

      final workDir = Directory.systemTemp.createTempSync('keel-codex-work-');
      addTearDown(() => workDir.deleteSync(recursive: true));

      final events = await const CodexCliRunner()
          .run(
            LlmTurnSpec(
              prompt: 'Llama la tool ping.',
              workingDirectory: workDir.path,
              model: '',
              fullFileSystemAccess: false,
              effort: 'medium',
              mcpConfig: jsonEncode({
                'mcpServers': {
                  'keel-test': {
                    'type': 'http',
                    'url': 'http://127.0.0.1:${mcp.port}/mcp',
                    'headers': {'Authorization': 'Bearer ${mcp.token}'},
                  },
                },
              }),
            ),
            userPath: Platform.environment['PATH'] ?? '',
            cancel: const Stream<void>.empty(),
          )
          .toList()
          .timeout(const Duration(seconds: 90));

      if (Platform.environment['KEEL_CODEX_DEBUG'] == '1') {
        // ignore: avoid_print
        print('tools offered: ${model.toolNamesSeen}');
        // ignore: avoid_print
        print('tool output seen by the model: ${model.toolOutputs}');
        // ignore: avoid_print
        print('events: $events');
      }

      // The oracle is the tool's own side effect, not what codex reports.
      expect(mcp.calls, 1, reason: 'the MCP tool never ran');
      expect(model.toolOutputs.join(), contains('pong'));
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'a codex file edit goes through Keel\'s permission gate',
    () async {
      final codexHome = Platform.environment['CODEX_HOME'] ?? '';
      expect(codexHome, isNot('${Platform.environment['HOME']}/.codex'));

      final gate = _FakeGateServer(decision: 'deny');
      await gate.start();
      addTearDown(gate.close);
      final model = _FakeModelProvider(
        firstCall: {
          'type': 'custom_tool_call',
          'id': 'ctc_1',
          'call_id': 'call_1',
          'name': 'apply_patch',
          'input':
              '*** Begin Patch\n*** Add File: nota.txt\n+hola\n*** End Patch\n',
        },
      );
      await model.start();
      addTearDown(model.close);
      _useFakeProvider(codexHome, model.port);

      final workDir = Directory.systemTemp.createTempSync('keel-codex-gate-');
      addTearDown(() => workDir.deleteSync(recursive: true));

      // The gate exactly as a Keel turn renders it for codex.
      final hooks = prepareTurnHooks(
        catalog: const [],
        tools: const [],
        secretValues: const {},
        provider: HookProvider.codex,
        gate: DecisionGateSpec(url: gate.url, token: gate.token),
      );

      await const CodexCliRunner()
          .run(
            LlmTurnSpec(
              prompt: 'Crea nota.txt.',
              workingDirectory: workDir.path,
              model: '',
              fullFileSystemAccess: false,
              effort: 'medium',
              hooksConfig: hooks.codexConfig,
              hookFiles: hooks.files,
            ),
            userPath: Platform.environment['PATH'] ?? '',
            cancel: const Stream<void>.empty(),
          )
          .toList()
          .timeout(const Duration(seconds: 90));

      expect(
        gate.asked.map((ask) => ask['tool_name']),
        contains('apply_patch'),
        reason: 'the edit never asked Keel for permission',
      );
      expect(File('${workDir.path}/nota.txt').existsSync(), isFalse);
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

/// Makes the fake provider codex's model provider for this run. The model
/// slug is a real one so codex offers its real tools (`apply_patch`).
void _useFakeProvider(String codexHome, int port, {String model = 'gpt-5.5'}) {
  File('$codexHome/config.toml').writeAsStringSync('''
model = "$model"
model_provider = "keel_fake"

[model_providers.keel_fake]
name = "keel fake"
base_url = "http://127.0.0.1:$port/v1"
wire_api = "responses"
requires_openai_auth = false
''');
}

/// Stands in for Keel's DecisionGateServer: records what the gate hook asked
/// and answers with [decision].
class _FakeGateServer {
  _FakeGateServer({required this.decision});

  final String decision;
  final String token = 'gate-token';
  final List<Map<String, dynamic>> asked = [];
  late final HttpServer _server;

  String get url => 'http://127.0.0.1:${_server.port}/gate/p/s/a';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((request) async {
      asked.add(
        jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>,
      );
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({'decision': decision, 'reason': 'Keel gate test'}),
      );
      await request.response.close();
    });
  }

  Future<void> close() => _server.close(force: true);
}

/// A streamable-HTTP MCP server with one tool, `ping`, behind a bearer token
/// — the shape of every Keel MCP server.
class _FakeMcpServer {
  final String token = 'keel-test-token';
  late final HttpServer _server;
  int calls = 0;

  int get port => _server.port;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handle);
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    if (request.headers.value('authorization') != 'Bearer $token') {
      response.statusCode = HttpStatus.unauthorized;
      await response.close();
      return;
    }
    if (request.method != 'POST') {
      response.statusCode = HttpStatus.methodNotAllowed;
      await response.close();
      return;
    }
    final message =
        jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>;
    final id = message['id'];
    if (id == null) {
      response.statusCode = HttpStatus.accepted;
      await response.close();
      return;
    }
    final result = switch (message['method']) {
      'initialize' => {
        'protocolVersion':
            (message['params'] as Map?)?['protocolVersion'] ?? '2025-06-18',
        'capabilities': {'tools': <String, dynamic>{}},
        'serverInfo': {'name': 'keel-test', 'version': '1.0.0'},
      },
      'tools/list' => {
        'tools': [
          {
            'name': 'ping',
            'description': 'Answers pong.',
            'inputSchema': {
              'type': 'object',
              'properties': <String, dynamic>{},
            },
          },
        ],
      },
      'tools/call' => () {
        calls++;
        return {
          'content': [
            {'type': 'text', 'text': 'pong'},
          ],
        };
      }(),
      _ => null,
    };
    response.headers.contentType = ContentType.json;
    response.write(
      jsonEncode(
        result == null
            ? {
                'jsonrpc': '2.0',
                'id': id,
                'error': {'code': -32601, 'message': 'not found'},
              }
            : {'jsonrpc': '2.0', 'id': id, 'result': result},
      ),
    );
    await response.close();
  }
}

/// A Responses-API provider: the first request answers with a call to the
/// tool whose name ends in [toolSuffix]; once a tool output comes back it
/// answers with plain text.
class _FakeModelProvider {
  _FakeModelProvider({this.toolSuffix = '', this.firstCall});

  final String toolSuffix;

  /// When set, the first response is exactly this output item (e.g. a
  /// codex `apply_patch` custom tool call) instead of an MCP tool call.
  final Map<String, dynamic>? firstCall;
  late final HttpServer _server;
  final List<String> toolNamesSeen = [];
  final List<String> toolOutputs = [];

  int get port => _server.port;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handle);
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    final raw = await utf8.decoder.bind(request).join();
    if (request.method != 'POST' || !request.uri.path.endsWith('/responses')) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }
    final body = jsonDecode(raw) as Map<String, dynamic>;
    final tools = body['tools'] as List? ?? const [];
    final names = _toolNames(tools);
    toolNamesSeen
      ..clear()
      ..addAll(names);
    final outputs = [
      for (final item in body['input'] as List? ?? const [])
        if (item is Map &&
            '${item['type']}'.endsWith('_output') &&
            item['output'] != null)
          jsonEncode(item['output']),
    ];
    toolOutputs.addAll(outputs);

    response.headers.contentType = ContentType('text', 'event-stream');
    void send(Map<String, dynamic> event) => response.write(
      'event: ${event['type']}\ndata: ${jsonEncode(event)}\n\n',
    );
    send({
      'type': 'response.created',
      'response': {'id': 'resp_1'},
    });
    final target = _namespacedTool(tools, toolSuffix);
    final custom = firstCall;
    if (outputs.isEmpty && custom != null) {
      send({
        'type': 'response.output_item.done',
        'output_index': 0,
        'item': custom,
      });
    } else if (outputs.isEmpty && target != null) {
      send({
        'type': 'response.output_item.done',
        'output_index': 0,
        'item': {
          'type': 'function_call',
          'id': 'fc_1',
          'call_id': 'call_1',
          'namespace': target.namespace,
          'name': target.name,
          'arguments': '{}',
        },
      });
    } else {
      send({
        'type': 'response.output_item.done',
        'output_index': 0,
        'item': {
          'type': 'message',
          'id': 'msg_1',
          'role': 'assistant',
          'content': [
            {'type': 'output_text', 'text': 'listo'},
          ],
        },
      });
    }
    send({
      'type': 'response.completed',
      'response': {
        'id': 'resp_1',
        'usage': {
          'input_tokens': 1,
          'input_tokens_details': {'cached_tokens': 0},
          'output_tokens': 1,
          'output_tokens_details': {'reasoning_tokens': 0},
          'total_tokens': 2,
        },
      },
    });
    await response.close();
  }

  /// The MCP tool ending in [suffix], with the namespace codex grouped it
  /// under (`mcp__<server>`): the model calls it by both.
  static ({String namespace, String name})? _namespacedTool(
    List<dynamic> tools,
    String suffix,
  ) {
    for (final group in tools) {
      if (group is! Map || group['type'] != 'namespace') continue;
      for (final tool in group['tools'] as List? ?? const []) {
        final name = tool is Map ? tool['name'] as String? : null;
        if (name != null && name.endsWith(suffix)) {
          return (namespace: group['name'] as String, name: name);
        }
      }
    }
    return null;
  }

  /// Tool names as the request lists them, flattening namespaced groups.
  static List<String> _toolNames(List<dynamic> tools) => [
    for (final tool in tools)
      if (tool is Map) ...[
        if (tool['name'] is String) tool['name'] as String,
        ..._toolNames(tool['tools'] as List? ?? const []),
      ],
  ];
}
