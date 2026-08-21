import 'package:flutter/foundation.dart';

final RegExp _toolNameFormat = RegExp(r'^[a-z0-9_-]{1,32}$');

/// Default wall-clock budget for one tool run. Deliberately short: these are
/// deterministic scripts (parse, convert, compute), not long jobs.
const kDefaultToolTimeoutSeconds = 60;

/// Hard ceiling for [Tool.timeoutSeconds] — a script that needs more than
/// this is not a tool, it's a job, and it doesn't belong inside a chat turn.
const kMaxToolTimeoutSeconds = 600;

/// Returns a human error message if [value] can't be used as a
/// [Tool.name], or null if it's valid. The name doubles as the MCP tool
/// identifier the model calls (`mcp__keel-tools__<name>`), so it has to be
/// a strict slug.
String? validateToolName(String value) {
  if (value.isEmpty) return 'El nombre no puede estar vacío.';
  if (value.length > 32) return 'Máximo 32 caracteres.';
  if (value.contains(' ')) return 'No se permiten espacios.';
  if (value != value.toLowerCase()) return 'Usa solo minúsculas.';
  if (!_toolNameFormat.hasMatch(value)) {
    return 'Solo letras minúsculas, números, "-" y "_".';
  }
  return null;
}

/// How a [Tool]'s code runs: which binary executes the script file and what
/// extension that file gets. The set is closed on purpose — a runtime the
/// machine can't be assumed to have (node, ruby…) earns its entry here only
/// when it's actually needed.
enum ToolRuntime {
  bash(alias: 'bash', label: 'Bash', executable: 'bash', fileExtension: 'sh'),
  python(
    alias: 'python',
    label: 'Python',
    executable: 'python3',
    fileExtension: 'py',
  ),
  dart(alias: 'dart', label: 'Dart', executable: 'dart', fileExtension: 'dart');

  final String alias;
  final String label;
  final String executable;
  final String fileExtension;

  const ToolRuntime({
    required this.alias,
    required this.label,
    required this.executable,
    required this.fileExtension,
  });

  static ToolRuntime? tryFromAlias(String alias) {
    for (final runtime in values) {
      if (runtime.alias == alias) return runtime;
    }
    return null;
  }

  factory ToolRuntime.fromAlias(String alias) {
    final runtime = tryFromAlias(alias);
    if (runtime == null) {
      throw ArgumentError.value(alias, 'alias', 'Runtime de tool desconocido');
    }
    return runtime;
  }
}

/// A registered, deterministic script an agent can invoke as a real MCP tool
/// instead of doing the work "by hand" in prose (e.g. parsing an Excel to
/// CSV). The [code] runs as a one-shot process under [runtime], receiving
/// the call's positional arguments as argv; stdout/stderr/exit code travel
/// back to the model. Which agents see it is static — decided by profile
/// assignment, never inferred at runtime.
class Tool {
  final String id;
  final String name;

  /// Shown verbatim to the model as the MCP tool description — it must say
  /// what the tool does, when to use it, and what each positional argument
  /// means.
  final String description;
  final ToolRuntime runtime;
  final String code;
  final int timeoutSeconds;

  /// Names of registered secrets injected as environment variables when the
  /// script runs. Only what a tool declares reaches its process — secrets
  /// are never ambient, and never reach the agent's own CLI.
  final List<String> secretNames;
  final DateTime createdAt;

  const Tool({
    required this.id,
    required this.name,
    required this.description,
    required this.runtime,
    required this.code,
    required this.timeoutSeconds,
    required this.createdAt,
    this.secretNames = const [],
  });

  Tool copyWith({
    String? name,
    String? description,
    ToolRuntime? runtime,
    String? code,
    int? timeoutSeconds,
    List<String>? secretNames,
  }) {
    return Tool(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      runtime: runtime ?? this.runtime,
      code: code ?? this.code,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      secretNames: secretNames ?? this.secretNames,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'runtime': runtime.alias,
    'code': code,
    'timeoutSeconds': timeoutSeconds,
    'secretNames': secretNames,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Tool.fromJson(Map<String, dynamic> json) {
    return Tool(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      runtime: ToolRuntime.fromAlias(json['runtime'] as String),
      code: json['code'] as String,
      timeoutSeconds: json['timeoutSeconds'] as int,
      secretNames: (json['secretNames'] as List?)?.cast<String>() ?? const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tool &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          runtime == other.runtime &&
          code == other.code &&
          timeoutSeconds == other.timeoutSeconds &&
          listEquals(secretNames, other.secretNames) &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    runtime,
    code,
    timeoutSeconds,
    Object.hashAll(secretNames),
    createdAt,
  );

  @override
  String toString() =>
      'Tool(id: $id, name: $name, runtime: ${runtime.alias}, '
      'description: ${description.length} chars, code: ${code.length} chars, '
      'timeoutSeconds: $timeoutSeconds, secretNames: $secretNames, '
      'createdAt: $createdAt)';
}

class ToolsState {
  final List<Tool> tools;

  const ToolsState({this.tools = const []});

  ToolsState copyWith({List<Tool>? tools}) {
    return ToolsState(tools: tools ?? this.tools);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToolsState &&
          runtimeType == other.runtimeType &&
          listEquals(tools, other.tools);

  @override
  int get hashCode => Object.hashAll(tools);

  @override
  String toString() => 'ToolsState(tools: ${tools.length})';
}
