import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/assistant_mcp/assistant_mcp_server.dart';
import 'package:keel_ui/src/integrations/llm/llm.dart';
import 'package:keel_ui/src/integrations/llm/openai_compatible/openai_tool_bridge.dart';

void main() {
  test('publica las tools de Keel AI desde su MCP HTTP local', () async {
    await AssistantMcpServer.start();
    final entry = AssistantMcpServer.mcpServerEntryFor('agent-test');
    expect(entry, isNotNull);
    final bridge = DefaultOpenAiToolBridge();
    addTearDown(bridge.close);
    final spec = LlmTurnSpec(
      prompt: 'inventariar workflows',
      workingDirectory: Directory.systemTemp.path,
      model: 'deepseek-chat',
      fullFileSystemAccess: false,
      effort: 'medium',
      extraAllowedTools: kKeelAiMcpToolNames,
      mcpConfig: jsonEncode({
        'mcpServers': {'keelai-actions': entry},
      }),
    );

    final functions = await bridge.functions(spec);

    expect(
      functions.map((function) => function.name),
      containsAll(const {
        'mcp__keelai-actions__list_catalog',
        'mcp__keelai-actions__list_workflows',
        'mcp__keelai-actions__list_projects',
        'mcp__keelai-actions__get_item',
        'mcp__keelai-actions__create_workflow',
      }),
    );
  });

  test('un MCP requerido que no carga falla en vez de desaparecer', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));
    final bridge = DefaultOpenAiToolBridge();
    addTearDown(bridge.close);
    final spec = LlmTurnSpec(
      prompt: 'inventariar workflows',
      workingDirectory: Directory.systemTemp.path,
      model: 'deepseek-chat',
      fullFileSystemAccess: false,
      effort: 'medium',
      extraAllowedTools: const ['mcp__keelai-actions__list_workflows'],
      mcpConfig: jsonEncode({
        'mcpServers': {
          'keelai-actions': {
            'type': 'http',
            'url': 'http://127.0.0.1:${server.port}/mcp/test',
          },
        },
      }),
    );

    expect(
      () => bridge.functions(spec),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('keelai-actions'),
        ),
      ),
    );
  });

  test(
    'publica y ejecuta solo herramientas autorizadas dentro del workspace',
    () async {
      final workspace = await Directory.systemTemp.createTemp(
        'keel_tool_test_',
      );
      addTearDown(() async {
        if (await workspace.exists()) await workspace.delete(recursive: true);
      });
      await File('${workspace.path}/README.md').writeAsString('hola');
      final outside = await Directory.systemTemp.createTemp(
        'keel_tool_outside_',
      );
      addTearDown(() async {
        if (await outside.exists()) await outside.delete(recursive: true);
      });
      await File('${outside.path}/secret.txt').writeAsString('secreto');
      await Link('${workspace.path}/escape').create(outside.path);
      final bridge = DefaultOpenAiToolBridge();
      addTearDown(bridge.close);
      final spec = LlmTurnSpec(
        prompt: 'leer',
        workingDirectory: workspace.path,
        model: 'model',
        fullFileSystemAccess: false,
        effort: 'medium',
        extraAllowedTools: const ['Edit'],
      );

      final functions = await bridge.functions(spec);
      expect(functions.map((entry) => entry.name), [
        'Read',
        'Glob',
        'Grep',
        'Edit',
      ]);
      expect(
        (await bridge.execute(spec, 'Read', {'path': 'README.md'})).content,
        'hola',
      );
      expect(
        (await bridge.execute(spec, 'Write', {
          'path': 'new.txt',
          'content': 'no',
        })).isError,
        isTrue,
      );
      expect(
        (await bridge.execute(spec, 'Read', {
          'path': '../outside.txt',
        })).isError,
        isTrue,
      );
      expect(
        (await bridge.execute(spec, 'Read', {
          'path': 'escape/secret.txt',
        })).isError,
        isTrue,
      );
    },
  );
}
