import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/mcp_servers/model/mcp_server_config.dart';

void main() {
  group('secrets adentro de un header', () {
    test('encuentra cada {{NOMBRE}} en el orden en que aparece', () {
      expect(secretPlaceholdersIn('Bearer {{LINEAR_API_KEY}}'), [
        'LINEAR_API_KEY',
      ]);
      expect(secretPlaceholdersIn('{{UNO}} y {{DOS}}'), ['UNO', 'DOS']);
      expect(secretPlaceholdersIn('sin nada'), isEmpty);
    });

    test('no confunde con algo que no tiene formato de secret', () {
      expect(secretPlaceholdersIn('{{minuscula}}'), isEmpty);
      expect(secretPlaceholdersIn('{{1EMPIEZA_CON_NUMERO}}'), isEmpty);
    });

    test('reemplaza dejando el resto del header intacto', () {
      final resolved = resolveSecretPlaceholders('Bearer {{TOKEN}}', {
        'TOKEN': 'abc123',
      });

      expect(resolved, 'Bearer abc123');
    });

    test('devuelve null si falta alguno, en vez de resolver a medias', () {
      final resolved = resolveSecretPlaceholders('{{UNO}}:{{DOS}}', {
        'UNO': 'a',
      });

      expect(resolved, isNull);
    });
  });

  group('la entrada que se le entrega al CLI', () {
    McpServerConfig remote(Map<String, String> headers) => McpServerConfig(
      id: 'x',
      name: 'linear',
      transport: McpTransport.http,
      url: 'https://mcp.linear.app/mcp',
      headers: headers,
      createdAt: DateTime(2026),
    );

    test('un header con secret sale resuelto', () {
      final entry = remote({
        'Authorization': 'Bearer {{TOKEN}}',
      }).toMcpServerEntry({'TOKEN': 'lin_api_9'});

      expect(entry['headers'], {'Authorization': 'Bearer lin_api_9'});
      expect(entry['type'], 'http');
    });

    test('un header cuyo secret falta se omite entero', () {
      final entry = remote({
        'Authorization': 'Bearer {{TOKEN}}',
        'X-Fijo': 'siempre',
      }).toMcpServerEntry(const {});

      expect(entry['headers'], {'X-Fijo': 'siempre'});
    });

    test('sse viaja con su propio type', () {
      final entry = McpServerConfig(
        id: 'x',
        name: 'atlassian',
        transport: McpTransport.sse,
        url: 'https://mcp.atlassian.com/v1/sse',
        createdAt: DateTime(2026),
      ).toMcpServerEntry(const {});

      expect(entry['type'], 'sse');
    });

    test('secretNames junta las dos formas de pedir un secret', () {
      final server = McpServerConfig(
        id: 'x',
        name: 'mixto',
        transport: McpTransport.http,
        url: 'https://ejemplo',
        headers: const {'Authorization': 'Bearer {{DEL_HEADER}}'},
        secretEnv: const {'CLAVE': 'DEL_ENTORNO'},
        createdAt: DateTime(2026),
      );

      expect(server.secretNames, containsAll(['DEL_HEADER', 'DEL_ENTORNO']));
    });
  });

  test('un servidor viejo, sin catalogId guardado, se lee igual', () {
    final server = McpServerConfig.fromJson({
      'id': 'x',
      'name': 'viejo',
      'transport': 'stdio',
      'command': 'npx',
      'args': <String>[],
      'env': <String, String>{},
      'secretEnv': <String, String>{},
      'url': '',
      'headers': <String, String>{},
      'createdAt': '2026-01-01T00:00:00.000',
    });

    expect(server.catalogId, isEmpty);
  });
}
