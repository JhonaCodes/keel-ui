import 'dart:convert';

import 'package:keel_ui/src/core/services/cli_turn_contract.dart';

/// What an `opencode serve` needs for Keel's turns: the config file it reads
/// (`OPENCODE_CONFIG`) and the environment that holds the secrets that file
/// only names.
class OpenCodeTurnConfig {
  const OpenCodeTurnConfig({required this.configJson, required this.environment});

  final String configJson;
  final Map<String, String> environment;
}

/// Prefix of the environment variables that carry an MCP server's secrets.
const kOpenCodeMcpEnvPrefix = 'KEEL_OC_';

/// The turn's `mcp.json` (the same claude receives) and permission policy,
/// in OpenCode's config format.
///
/// - Secrets never go in the file: headers and a local server's environment
///   are written as `{env:VAR}` and the values travel in [environment].
/// - OpenCode gives each MCP server 5 s by default; `ask_user` and Keel's
///   own tools wait for a person, so they get the same deadline as claude.
/// - Permissions: reading is free. Commands and edits ask when Keel has a
///   gate to answer ([hasGate]); with none they run inside the workspace, or
///   are denied when the turn may not write ([readOnly]). OpenCode's own
///   `question` tool is off — agents ask through Keel's `ask_user`.
OpenCodeTurnConfig buildOpenCodeConfig({
  required String? mcpConfigJson,
  required bool hasGate,
  required bool readOnly,
  required bool fullDiskAccess,
}) {
  final environment = <String, String>{};
  final mcp = <String, dynamic>{};
  final decoded = mcpConfigJson == null || mcpConfigJson.isEmpty
      ? null
      : jsonDecode(mcpConfigJson);
  final servers = decoded is Map ? decoded['mcpServers'] : null;
  if (servers is Map) {
    for (final entry in servers.entries) {
      final name = '${entry.key}';
      final server = entry.value;
      if (server is! Map) continue;
      final url = server['url'];
      final command = server['command'];
      if (url is String && url.isNotEmpty) {
        mcp[name] = {
          'type': 'remote',
          'url': url,
          'oauth': false,
          'timeout': kMcpToolTimeoutMillis,
          if (server['headers'] case final Map headers when headers.isNotEmpty)
            'headers': {
              for (final header in headers.entries)
                '${header.key}': _secret(
                  environment,
                  '${name}_${header.key}',
                  '${header.value}',
                ),
            },
        };
      } else if (command is String && command.isNotEmpty) {
        mcp[name] = {
          'type': 'local',
          'command': [
            command,
            for (final arg in server['args'] as List? ?? const []) '$arg',
          ],
          'timeout': kMcpToolTimeoutMillis,
          if (server['env'] case final Map env when env.isNotEmpty)
            'environment': {
              for (final variable in env.entries)
                '${variable.key}': _secret(
                  environment,
                  '${name}_${variable.key}',
                  '${variable.value}',
                ),
            },
        };
      }
    }
  }

  final write = readOnly
      ? 'deny'
      : hasGate
      ? 'ask'
      : 'allow';
  return OpenCodeTurnConfig(
    configJson: jsonEncode({
      r'$schema': 'https://opencode.ai/config.json',
      'mcp': mcp,
      'permission': {
        'read': 'allow',
        'list': 'allow',
        'glob': 'allow',
        'grep': 'allow',
        'webfetch': 'allow',
        'edit': write,
        'bash': write,
        'external_directory': fullDiskAccess && !readOnly
            ? 'allow'
            : hasGate
            ? 'ask'
            : 'deny',
        'question': 'deny',
        // Subagents: every `task` asks, and the runner answers by itself
        // with how many are already running (`SubagentLimits.maxParallel`).
        'task': 'ask',
      },
    }),
    environment: environment,
  );
}

/// Stores [value] under a derived variable name and returns the reference
/// OpenCode resolves at runtime.
String _secret(Map<String, String> environment, String key, String value) {
  final variable =
      '$kOpenCodeMcpEnvPrefix${key.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '_')}';
  environment[variable] = value;
  return '{env:$variable}';
}
