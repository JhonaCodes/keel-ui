import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/mcp_catalog/mcp_catalog.dart';
import 'package:keel_ui/src/modules/mcp_servers/model/mcp_server_config.dart';

void main() {
  group('pegar una configuración MCP', () {
    test('lee el bloque con su clave mcpServers', () {
      final parsed = parseMcpServersJson('''
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest"]
    }
  }
}
''');

      expect(parsed.error, isEmpty);
      expect(parsed.servers.single.name, 'playwright');
      expect(parsed.servers.single.transport, McpTransport.stdio);
      expect(parsed.servers.single.args, ['-y', '@playwright/mcp@latest']);
    });

    test('lee también el mapa pelado, sin la clave de afuera', () {
      final parsed = parseMcpServersJson(
        '{"context7": {"command": "npx", "args": ["-y", "@upstash/context7-mcp"]}}',
      );

      expect(parsed.servers.single.name, 'context7');
    });

    test('un remoto sin type se toma como http', () {
      final parsed = parseMcpServersJson(
        '{"linear": {"url": "https://mcp.linear.app/mcp"}}',
      );

      expect(parsed.servers.single.transport, McpTransport.http);
    });

    test('un remoto con type sse conserva su transporte', () {
      final parsed = parseMcpServersJson(
        '{"atlassian": {"type": "sse", "url": "https://x/sse"}}',
      );

      expect(parsed.servers.single.transport, McpTransport.sse);
    });

    test('marca los env que parecen credenciales, sin bloquear', () {
      final parsed = parseMcpServersJson('''
{"postgres": {
  "command": "npx",
  "env": {"DATABASE_URL": "postgres://u:p@h/d", "PGPORT": "5432"}
}}
''');

      final server = parsed.servers.single;
      expect(server.sensitiveEnvKeys, ['DATABASE_URL']);
      expect(server.env['PGPORT'], '5432');
    });

    test('un env sensible pero vacío no se marca', () {
      final parsed = parseMcpServersJson(
        '{"x": {"command": "npx", "env": {"API_TOKEN": ""}}}',
      );

      expect(parsed.servers.single.sensitiveEnvKeys, isEmpty);
    });

    test('lo que no se puede leer se nombra en vez de desaparecer', () {
      final parsed = parseMcpServersJson('''
{"mcpServers": {
  "bueno": {"command": "npx"},
  "NOMBRE MAL": {"command": "npx"},
  "sin-nada": {},
  "raro": "una string"
}}
''');

      expect(parsed.servers.map((server) => server.name), ['bueno']);
      expect(parsed.problems, hasLength(3));
      expect(parsed.problems.join(), contains('NOMBRE MAL'));
      expect(parsed.problems.join(), contains('sin-nada'));
      expect(parsed.problems.join(), contains('raro'));
    });

    test('un JSON roto lo dice, y no devuelve nada a medias', () {
      final parsed = parseMcpServersJson('{no es json');

      expect(parsed.error, isNotEmpty);
      expect(parsed.servers, isEmpty);
    });

    test('vacío es vacío, no un error', () {
      final parsed = parseMcpServersJson('   ');

      expect(parsed.error, isEmpty);
      expect(parsed.servers, isEmpty);
    });

    test('un valor numérico en env se convierte en vez de perderse', () {
      final parsed = parseMcpServersJson(
        '{"x": {"command": "npx", "env": {"PORT": 5432}}}',
      );

      expect(parsed.servers.single.env['PORT'], '5432');
    });
  });
}
