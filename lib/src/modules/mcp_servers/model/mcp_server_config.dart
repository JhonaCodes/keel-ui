import 'package:flutter/foundation.dart';

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
  http(alias: 'http', label: 'Remoto (HTTP)');

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

  /// http only.
  final String url;
  final Map<String, String> headers;

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
      McpTransport.http => {'type': 'http', 'url': url, 'headers': headers},
    };
  }

  /// Every secret NAME this server references.
  List<String> get secretNames => secretEnv.values.toList();

  McpServerConfig copyWith({
    String? name,
    McpTransport? transport,
    String? command,
    List<String>? args,
    Map<String, String>? env,
    Map<String, String>? secretEnv,
    String? url,
    Map<String, String>? headers,
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

  const McpServersState({this.servers = const []});

  McpServersState copyWith({List<McpServerConfig>? servers}) {
    return McpServersState(servers: servers ?? this.servers);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is McpServersState &&
          runtimeType == other.runtimeType &&
          listEquals(servers, other.servers);

  @override
  int get hashCode => Object.hashAll(servers);

  @override
  String toString() => 'McpServersState(servers: ${servers.length})';
}
