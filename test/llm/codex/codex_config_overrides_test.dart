import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/llm/codex/codex_config_overrides.dart';
import 'package:keel_ui/src/shared/utils/toml_string.dart';

void main() {
  group('codexMcpConfig', () {
    test('sin servidores no hay nada', () {
      expect(codexMcpConfig(null).overrides, isEmpty);
      expect(codexMcpConfig('{"mcpServers":{}}').overrides, isEmpty);
    });

    test('un servidor HTTP: url por -c, headers por variable de entorno', () {
      final config = codexMcpConfig(
        jsonEncode({
          'mcpServers': {
            'keel-decisions': {
              'type': 'http',
              'url': 'http://127.0.0.1:4321/ask/p/s/a',
              'headers': {'Authorization': 'Bearer secreto-123'},
            },
          },
        }),
      );

      expect(
        config.overrides,
        containsAll([
          'mcp_servers.keel-decisions.url="http://127.0.0.1:4321/ask/p/s/a"',
          'mcp_servers.keel-decisions.env_http_headers='
              '{Authorization="KEEL_MCP_HEADER_KEEL_DECISIONS_AUTHORIZATION"}',
          'mcp_servers.keel-decisions.tool_timeout_sec=21600',
        ]),
      );
      expect(config.overrides.join('\n'), isNot(contains('secreto-123')));
      expect(
        config.environment['KEEL_MCP_HEADER_KEEL_DECISIONS_AUTHORIZATION'],
        'Bearer secreto-123',
      );
    });

    test('un servidor stdio: command y args por -c, env por env_vars', () {
      final config = codexMcpConfig(
        jsonEncode({
          'mcpServers': {
            'github': {
              'command': 'npx',
              'args': ['-y', 'gh-mcp'],
              'env': {'GITHUB_TOKEN': 'ghp-secreto'},
            },
          },
        }),
      );

      expect(
        config.overrides,
        containsAll([
          'mcp_servers.github.command="npx"',
          'mcp_servers.github.args=["-y","gh-mcp"]',
          'mcp_servers.github.env_vars=["GITHUB_TOKEN"]',
        ]),
      );
      expect(config.overrides.join('\n'), isNot(contains('ghp-secreto')));
      expect(config.environment['GITHUB_TOKEN'], 'ghp-secreto');
    });
  });

  group('tomlString', () {
    test('escapa barra, comilla, salto de línea y control', () {
      final control = String.fromCharCode(1);
      expect(
        tomlString('a\\b"c\n\t$control'),
        r'"a\\b\"c\n\t\u0001"',
      );
    });
  });
}
