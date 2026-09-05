import 'dart:convert';

import 'package:keel_ui/src/core/services/cli_turn_contract.dart';
import 'package:keel_ui/src/shared/utils/toml_string.dart';

/// Lo que un turno de codex recibe por `-c clave=valor` y por el entorno
/// del proceso, en vez de por archivos.
///
/// Codex 0.153 no acepta `-p <perfil>` en `exec resume` y rechaza
/// `-c profile=...` («legacy»), así que un perfil TOML por turno ya no
/// sirve para reanudar. Lo único que `exec` y `exec resume` aceptan por
/// igual es `-c`, y eso es lo que se usa para hooks, MCP y las
/// instrucciones de rol (verificado con el binario, 2026-09-05).
///
/// Los valores secretos NUNCA van en [overrides]: un argumento de línea de
/// comandos es legible con `ps`. Van en [environment], y el override apunta
/// al nombre de la variable (`bearer_token_env_var`, `env_http_headers`,
/// `env_vars`), que codex resuelve del entorno del proceso.
class CodexTurnConfig {
  final List<String> overrides;
  final Map<String, String> environment;

  const CodexTurnConfig({this.overrides = const [], this.environment = const {}});

  static const none = CodexTurnConfig();
}

/// Prefijo de las variables de entorno que llevan los headers de los MCP
/// HTTP de un turno.
const kCodexMcpHeaderEnvPrefix = 'KEEL_MCP_HEADER_';

/// El bloque `mcpServers` de un `mcp.json` (el mismo que recibe claude),
/// traducido a overrides de codex.
///
/// - HTTP/SSE: `url`, y cada header como `env_http_headers = {Header =
///   "VARIABLE"}` con el valor en el entorno. `Authorization: Bearer x` no
///   es distinto de cualquier otro header: va igual, por variable.
/// - stdio: `command`, `args`, y las variables de `env` se le pasan al
///   proceso de codex, que las reenvía al servidor por `env_vars` (los
///   hijos de codex NO heredan el entorno; solo lo que se nombra ahí).
///
/// Todos con `tool_timeout_sec` en el mismo plazo que `MCP_TOOL_TIMEOUT` de
/// claude: `ask_user` y el gate esperan a una persona.
CodexTurnConfig codexMcpConfig(String? mcpConfigJson) {
  if (mcpConfigJson == null || mcpConfigJson.isEmpty) {
    return CodexTurnConfig.none;
  }
  final decoded = jsonDecode(mcpConfigJson);
  final servers = decoded is Map ? decoded['mcpServers'] : null;
  if (servers is! Map || servers.isEmpty) return CodexTurnConfig.none;

  final overrides = <String>[];
  final environment = <String, String>{};
  final toolTimeoutSec = kMcpToolTimeoutMillis ~/ 1000;

  for (final entry in servers.entries) {
    final name = entry.key as String;
    final server = entry.value;
    if (server is! Map) continue;
    final key = 'mcp_servers.${_tomlKey(name)}';
    final url = server['url'];
    final command = server['command'];

    if (url is String && url.isNotEmpty) {
      overrides.add('$key.url=${tomlString(url)}');
      final headers = server['headers'];
      if (headers is Map && headers.isNotEmpty) {
        final pairs = <String>[];
        for (final header in headers.entries) {
          final headerName = header.key as String;
          final variable =
              '$kCodexMcpHeaderEnvPrefix${_envSlug(name)}_${_envSlug(headerName)}';
          environment[variable] = '${header.value}';
          pairs.add('${_tomlKey(headerName)}=${tomlString(variable)}');
        }
        overrides.add('$key.env_http_headers={${pairs.join(',')}}');
      }
    } else if (command is String && command.isNotEmpty) {
      overrides.add('$key.command=${tomlString(command)}');
      final args = server['args'];
      if (args is List) {
        overrides.add(
          '$key.args=[${args.map((arg) => tomlString('$arg')).join(',')}]',
        );
      }
      final env = server['env'];
      if (env is Map && env.isNotEmpty) {
        final names = <String>[];
        for (final variable in env.entries) {
          final variableName = variable.key as String;
          environment[variableName] = '${variable.value}';
          names.add(tomlString(variableName));
        }
        overrides.add('$key.env_vars=[${names.join(',')}]');
      }
    } else {
      continue;
    }
    overrides.add('$key.tool_timeout_sec=$toolTimeoutSec');
  }
  return CodexTurnConfig(overrides: overrides, environment: environment);
}

/// Una clave TOML: pelada si es un identificador simple, entre comillas si
/// no (un nombre de servidor con espacios o puntos).
String _tomlKey(String name) =>
    RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(name) ? name : tomlString(name);

String _envSlug(String value) => value
    .toUpperCase()
    .replaceAll(RegExp(r'[^A-Z0-9]'), '_');
