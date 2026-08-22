import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/modules/mcp_servers/model/mcp_probe_result.dart';

final RegExp _mcpServerNameFormat = RegExp(r'^[a-z0-9_-]{1,32}$');

/// Returns a human error message if [value] can't be used as a
/// [McpServerConfig.name], or null if it's valid. The name becomes the MCP
/// server key, and with it the tool prefix `mcp__<name>__*`.
String? validateMcpServerName(String value) {
  if (value.isEmpty) return 'El nombre no puede estar vacío.';
  if (!_mcpServerNameFormat.hasMatch(value)) {
    return 'Solo minúsculas, números, "-" y "_" (máx. 32).';
  }
  return null;
}

enum McpTransport {
  stdio(alias: 'stdio', label: 'Local (stdio)'),
  http(alias: 'http', label: 'Remoto (HTTP)'),

  /// Server-sent events. Sigue siendo el transporte de varios servidores
  /// remotos publicados (Atlassian, entre otros), así que el catálogo no
  /// puede describirlos sin él. Para todo lo demás se comporta como http:
  /// una URL y headers.
  sse(alias: 'sse', label: 'Remoto (SSE)');

  final String alias;
  final String label;

  const McpTransport({required this.alias, required this.label});

  static McpTransport? tryFromAlias(String alias) {
    for (final transport in values) {
      if (transport.alias == alias) return transport;
    }
    return null;
  }

  factory McpTransport.fromAlias(String alias) {
    final transport = tryFromAlias(alias);
    if (transport == null) {
      throw ArgumentError.value(alias, 'alias', 'Transporte MCP desconocido');
    }
    return transport;
  }
}

final RegExp _secretPlaceholder = RegExp(r'\{\{([A-Z][A-Z0-9_]{0,63})\}\}');

/// Every secret NAME referenced as `{{NOMBRE}}` inside [value], in the order
/// they appear. Used for header values, where the secret is almost never the
/// whole thing: an `Authorization` needs `Bearer ` in front of it, so a map
/// of key→secret couldn't express it.
List<String> secretPlaceholdersIn(String value) => [
  for (final match in _secretPlaceholder.allMatches(value)) match.group(1)!,
];

/// Replaces every `{{NOMBRE}}` in [value] with its secret. Returns null when
/// any referenced secret is missing: half-resolved is worse than absent — an
/// `Authorization: Bearer ` with nothing after it makes a server answer 400
/// where the missing header would have answered a legible 401.
String? resolveSecretPlaceholders(
  String value,
  Map<String, String> secretValues,
) {
  var resolved = value;
  for (final name in secretPlaceholdersIn(value)) {
    final secret = secretValues[name];
    if (secret == null) return null;
    resolved = resolved.replaceAll('{{$name}}', secret);
  }
  return resolved;
}

/// A registered EXTERNAL MCP server (gmail, drive, github, …) agents can be
/// granted per profile. Stdio servers run a local command with env vars;
/// http servers point at a URL with headers. Credentials never live here as
/// plain data when they can be a secret reference: [secretEnv] maps an env
/// KEY to a registered secret NAME, resolved to its value only at turn
/// time, inside the mcp-config temp file.
class McpServerConfig {
  final String id;
  final String name;
  final McpTransport transport;

  /// stdio only: the executable and its arguments.
  final String command;
  final List<String> args;

  /// stdio only: literal (non-sensitive) environment values.
  final Map<String, String> env;

  /// stdio only: env KEY → registered secret NAME (resolved at turn time).
  final Map<String, String> secretEnv;

  /// Remoto (http/sse). A header VALUE may reference a secret as
  /// `{{NOMBRE}}`;
  /// it resolves at turn time, inside the mcp-config temp file.
  final String url;
  final Map<String, String> headers;

  /// The catalog entry this was installed from (`github`, `linear`, …), or
  /// empty when it was registered by hand. Only decorates the UI — the
  /// config is the truth, and stays editable after installing.
  final String catalogId;

  final DateTime createdAt;

  const McpServerConfig({
    required this.id,
    required this.name,
    required this.transport,
    required this.createdAt,
    this.command = '',
    this.args = const [],
    this.env = const {},
    this.secretEnv = const {},
    this.url = '',
    this.headers = const {},
    this.catalogId = '',
  });

  /// The `mcpServers` entry the claude CLI understands, with secret
  /// references already resolved by the caller ([secretValues] maps secret
  /// NAME → value; missing ones are skipped so the server sees "unset", not
  /// an empty string).
  Map<String, dynamic> toMcpServerEntry(Map<String, String> secretValues) {
    return switch (transport) {
      McpTransport.stdio => {
        'command': command,
        'args': args,
        'env': {
          ...env,
          for (final entry in secretEnv.entries)
            if (secretValues.containsKey(entry.value))
              entry.key: secretValues[entry.value]!,
        },
      },
      McpTransport.http || McpTransport.sse => {
        'type': transport.alias,
        'url': url,
        'headers': {
          for (final entry in headers.entries)
            entry.key: ?resolveSecretPlaceholders(entry.value, secretValues),
        },
      },
    };
  }

  /// Every secret NAME this server references, from both places it can:
  /// the env map of a stdio server and the header templates of an http one.
  List<String> get secretNames => {
    ...secretEnv.values,
    for (final value in headers.values) ...secretPlaceholdersIn(value),
  }.toList();

  McpServerConfig copyWith({
    String? name,
    McpTransport? transport,
    String? command,
    List<String>? args,
    Map<String, String>? env,
    Map<String, String>? secretEnv,
    String? url,
    Map<String, String>? headers,
    String? catalogId,
  }) {
    return McpServerConfig(
      id: id,
      name: name ?? this.name,
      transport: transport ?? this.transport,
      command: command ?? this.command,
      args: args ?? this.args,
      env: env ?? this.env,
      secretEnv: secretEnv ?? this.secretEnv,
      url: url ?? this.url,
      headers: headers ?? this.headers,
      catalogId: catalogId ?? this.catalogId,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'transport': transport.alias,
    'command': command,
    'args': args,
    'env': env,
    'secretEnv': secretEnv,
    'url': url,
    'headers': headers,
    'catalogId': catalogId,
    'createdAt': createdAt.toIso8601String(),
  };

  factory McpServerConfig.fromJson(Map<String, dynamic> json) {
    return McpServerConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      transport: McpTransport.fromAlias(json['transport'] as String),
      command: json['command'] as String? ?? '',
      args: (json['args'] as List?)?.cast<String>() ?? const [],
      env: (json['env'] as Map?)?.cast<String, String>() ?? const {},
      secretEnv:
          (json['secretEnv'] as Map?)?.cast<String, String>() ?? const {},
      url: json['url'] as String? ?? '',
      headers: (json['headers'] as Map?)?.cast<String, String>() ?? const {},
      catalogId: json['catalogId'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is McpServerConfig &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          transport == other.transport &&
          command == other.command &&
          listEquals(args, other.args) &&
          mapEquals(env, other.env) &&
          mapEquals(secretEnv, other.secretEnv) &&
          url == other.url &&
          mapEquals(headers, other.headers) &&
          catalogId == other.catalogId &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    transport,
    command,
    Object.hashAll(args),
    Object.hashAll(env.entries.map((e) => Object.hash(e.key, e.value))),
    Object.hashAll(secretEnv.entries.map((e) => Object.hash(e.key, e.value))),
    url,
    Object.hashAll(headers.entries.map((e) => Object.hash(e.key, e.value))),
    catalogId,
    createdAt,
  );

  @override
  String toString() =>
      'McpServerConfig(id: $id, name: $name, transport: ${transport.alias}, '
      'command: $command, args: ${args.length}, env: ${env.keys.toList()}, '
      'secretEnv: $secretEnv, url: $url, createdAt: $createdAt)';
}

/// Parses `KEY=VALUE` lines (one per line, empty lines ignored) into a map.
/// Lines without `=` are skipped — deliberately forgiving for a form field.
Map<String, String> parseKeyValueLines(String raw) {
  final result = <String, String>{};
  for (final line in raw.split('\n')) {
    final separator = line.indexOf('=');
    if (separator <= 0) continue;
    final key = line.substring(0, separator).trim();
    if (key.isEmpty) continue;
    result[key] = line.substring(separator + 1).trim();
  }
  return result;
}

/// Inverse of [parseKeyValueLines], for prefilling the form on edit.
String formatKeyValueLines(Map<String, String> map) =>
    map.entries.map((entry) => '${entry.key}=${entry.value}').join('\n');

class McpServersState {
  final List<McpServerConfig> servers;

  /// El último probe de cada servidor, por id. No es configuración: es lo
  /// que contestó esta máquina la última vez que se preguntó.
  final Map<String, McpProbeResult> probes;

  /// Los que se están probando ahora. Un `Set` y no un bool porque probar
  /// tres a la vez es lo normal cuando acabás de restaurar un respaldo.
  final Set<String> probing;

  const McpServersState({
    this.servers = const [],
    this.probes = const {},
    this.probing = const {},
  });

  McpServersState copyWith({
    List<McpServerConfig>? servers,
    Map<String, McpProbeResult>? probes,
    Set<String>? probing,
  }) {
    return McpServersState(
      servers: servers ?? this.servers,
      probes: probes ?? this.probes,
      probing: probing ?? this.probing,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is McpServersState &&
          runtimeType == other.runtimeType &&
          listEquals(servers, other.servers) &&
          mapEquals(probes, other.probes) &&
          setEquals(probing, other.probing);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(servers),
    Object.hashAll(probes.keys),
    Object.hashAll(probing),
  );

  @override
  String toString() =>
      'McpServersState(servers: ${servers.length}, '
      'probes: ${probes.length}, probing: ${probing.length})';
}
