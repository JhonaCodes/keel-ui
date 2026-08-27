import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import 'package:keel_ui/src/core/services/cli_turn_workspace.dart';
import 'package:keel_ui/src/integrations/llm/llm.dart';

class OpenAiFunctionDefinition {
  const OpenAiFunctionDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  Map<String, dynamic> toJson() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': parameters,
    },
  };
}

class OpenAiToolResult {
  const OpenAiToolResult({required this.content, this.isError = false});

  final String content;
  final bool isError;
}

abstract interface class OpenAiToolBridge {
  Future<List<OpenAiFunctionDefinition>> functions(LlmTurnSpec spec);

  Future<OpenAiToolResult> execute(
    LlmTurnSpec spec,
    String name,
    Map<String, dynamic> arguments,
  );

  Future<void> close();
}

/// Adapts Keel's scoped workspace operations and per-turn MCP configuration
/// to OpenAI function tools. It receives only the same grants the CLI would
/// receive; no catalog or secret vault is reachable from the worker isolate.
class DefaultOpenAiToolBridge implements OpenAiToolBridge {
  final Map<String, _ToolBinding> _bindings = {};
  final List<_McpConnection> _connections = [];
  CliTurnWorkspace? _workspace;
  Map<String, dynamic> _hooks = const {};

  @override
  Future<List<OpenAiFunctionDefinition>> functions(LlmTurnSpec spec) async {
    if (_bindings.isNotEmpty) {
      return _bindings.values.map((binding) => binding.definition).toList();
    }
    _workspace = await CliTurnWorkspace.create(
      claudeSettings: spec.hooksSettings,
      hookFiles: spec.hookFiles,
    );
    final settingsPath = _workspace?.claudeSettingsPath;
    if (settingsPath != null) {
      final decoded = jsonDecode(await File(settingsPath).readAsString());
      if (decoded is Map<String, dynamic>) _hooks = decoded;
    }

    for (final binding in _workspaceBindings(spec)) {
      _bindings[binding.definition.name] = binding;
    }
    await _loadMcpBindings(spec);
    return _bindings.values.map((binding) => binding.definition).toList();
  }

  @override
  Future<OpenAiToolResult> execute(
    LlmTurnSpec spec,
    String name,
    Map<String, dynamic> arguments,
  ) async {
    final binding = _bindings[name];
    if (binding == null) {
      return OpenAiToolResult(
        content: jsonEncode({
          'ok': false,
          'error': 'Tool no autorizada: $name',
        }),
        isError: true,
      );
    }
    final preflight = await _runHooks(
      spec,
      event: 'PreToolUse',
      toolName: name,
      input: arguments,
    );
    if (preflight != null) return preflight;
    OpenAiToolResult result;
    try {
      result = await binding.execute(arguments);
    } catch (error) {
      result = OpenAiToolResult(
        content: jsonEncode({'ok': false, 'error': '$error'}),
        isError: true,
      );
    }
    await _runHooks(
      spec,
      event: result.isError ? 'PostToolUseFailure' : 'PostToolUse',
      toolName: name,
      input: arguments,
      result: result.content,
    );
    return result;
  }

  Future<OpenAiToolResult?> _runHooks(
    LlmTurnSpec spec, {
    required String event,
    required String toolName,
    required Map<String, dynamic> input,
    String? result,
  }) async {
    final hooks = (_hooks['hooks'] as Map?)?[event] as List? ?? const [];
    for (final group in hooks.whereType<Map>()) {
      final matcher = group['matcher'] as String? ?? '';
      if (matcher.isNotEmpty && !RegExp(matcher).hasMatch(toolName)) continue;
      for (final hook
          in (group['hooks'] as List? ?? const []).whereType<Map>()) {
        final command = hook['command'] as String?;
        if (command == null || command.isEmpty) continue;
        final process = await Process.start('/bin/sh', [
          '-lc',
          command,
        ], workingDirectory: spec.workingDirectory);
        process.stdin.write(
          jsonEncode({
            'hook_event_name': event,
            'tool_name': toolName,
            'tool_input': input,
            'tool_response': ?result,
            'cwd': spec.workingDirectory,
          }),
        );
        await process.stdin.close();
        final stderr = await process.stderr.transform(utf8.decoder).join();
        final stdout = await process.stdout.transform(utf8.decoder).join();
        final exitCode = await process.exitCode.timeout(
          Duration(seconds: (hook['timeout'] as num?)?.toInt() ?? 60),
          onTimeout: () {
            process.kill();
            return 124;
          },
        );
        if (event == 'PreToolUse' && exitCode != 0) {
          return OpenAiToolResult(
            content: jsonEncode({
              'ok': false,
              'error': stderr.trim().isEmpty ? stdout.trim() : stderr.trim(),
              'hook': hook['statusMessage'] ?? command,
            }),
            isError: true,
          );
        }
      }
    }
    return null;
  }

  Iterable<_ToolBinding> _workspaceBindings(LlmTurnSpec spec) sync* {
    yield _workspaceTool(
      name: 'Read',
      description: 'Read a UTF-8 file inside the turn workspace.',
      properties: {
        'path': _stringSchema('Absolute or workspace-relative file path.'),
      },
      required: const ['path'],
      run: (arguments) => _read(spec, arguments),
    );
    yield _workspaceTool(
      name: 'Glob',
      description: 'List workspace files matching a glob-like pattern.',
      properties: {'pattern': _stringSchema('Pattern such as **/*.dart.')},
      required: const ['pattern'],
      run: (arguments) => _glob(spec, arguments),
    );
    yield _workspaceTool(
      name: 'Grep',
      description:
          'Search text with a regular expression inside the workspace.',
      properties: {
        'pattern': _stringSchema('Regular expression.'),
        'path': _stringSchema('Optional directory or file.'),
      },
      required: const ['pattern'],
      run: (arguments) => _grep(spec, arguments),
    );
    if (_allowed(spec, 'Write')) {
      yield _workspaceTool(
        name: 'Write',
        description: 'Write a UTF-8 file inside the workspace.',
        properties: {
          'path': _stringSchema('File path.'),
          'content': _stringSchema('Complete new content.'),
        },
        required: const ['path', 'content'],
        run: (arguments) => _write(spec, arguments),
      );
    }
    if (_allowed(spec, 'Edit') || _allowed(spec, 'MultiEdit')) {
      yield _workspaceTool(
        name: 'Edit',
        description: 'Replace one exact text occurrence in a workspace file.',
        properties: {
          'path': _stringSchema('File path.'),
          'old_text': _stringSchema('Exact text occurring once.'),
          'new_text': _stringSchema('Replacement text.'),
        },
        required: const ['path', 'old_text', 'new_text'],
        run: (arguments) => _edit(spec, arguments),
      );
    }
    if (_allowed(spec, 'Bash')) {
      yield _workspaceTool(
        name: 'Bash',
        description: 'Run a shell command in the scoped working directory.',
        properties: {'command': _stringSchema('Shell command.')},
        required: const ['command'],
        run: (arguments) => _bash(spec, arguments),
      );
    }
  }

  Future<void> _loadMcpBindings(LlmTurnSpec spec) async {
    final config = spec.mcpConfig;
    if (config == null || config.trim().isEmpty) return;
    final decoded = jsonDecode(config);
    final servers = decoded is Map ? decoded['mcpServers'] as Map? : null;
    if (servers == null) return;
    for (final entry in servers.entries) {
      if (entry.key is! String || entry.value is! Map) continue;
      final serverName = entry.key as String;
      if (!_serverIsGranted(spec, serverName)) continue;
      final data = (entry.value as Map).cast<String, dynamic>();
      final connection = data['command'] is String
          ? _StdioMcpConnection(serverName, data)
          : _HttpMcpConnection(serverName, data);
      try {
        final tools = await connection.initializeAndList();
        _connections.add(connection);
        for (final tool in tools) {
          final grantedName = 'mcp__${serverName}__${tool.name}';
          if (!_allowed(spec, grantedName) &&
              !_allowed(spec, 'mcp__$serverName')) {
            continue;
          }
          final exposed = _openAiFunctionName(grantedName);
          _bindings[exposed] = _ToolBinding(
            OpenAiFunctionDefinition(
              name: exposed,
              description: tool.description,
              parameters: tool.inputSchema,
            ),
            (arguments) => connection.call(tool.name, arguments),
          );
        }
      } catch (error) {
        await connection.close();
        throw StateError(
          'No se pudo cargar el MCP requerido "$serverName": $error',
        );
      }
    }
  }

  bool _serverIsGranted(LlmTurnSpec spec, String serverName) {
    final serverGrant = 'mcp__$serverName';
    final toolPrefix = '${serverGrant}__';
    return spec.extraAllowedTools.any(
      (name) => name == serverGrant || name.startsWith(toolPrefix),
    );
  }

  /// Las tools que cambian algo. En modo plan no se ofrecen: acá el freno no
  /// puede ser una instrucción, porque un proveedor por API no tiene sandbox
  /// ni modo plan propio. Una tool que no está en el catálogo no se puede
  /// llamar; un pedido de no usarla, sí se puede ignorar.
  static const _writeTools = {
    'Write',
    'Edit',
    'MultiEdit',
    'NotebookEdit',
    'Bash',
  };

  bool _allowed(LlmTurnSpec spec, String name) {
    if (spec.planMode && _writeTools.contains(name)) return false;
    return spec.extraAllowedTools.contains(name);
  }

  _ToolBinding _workspaceTool({
    required String name,
    required String description,
    required Map<String, dynamic> properties,
    required List<String> required,
    required Future<OpenAiToolResult> Function(Map<String, dynamic>) run,
  }) => _ToolBinding(
    OpenAiFunctionDefinition(
      name: name,
      description: description,
      parameters: {
        'type': 'object',
        'properties': properties,
        'required': required,
        'additionalProperties': false,
      },
    ),
    run,
  );

  Future<OpenAiToolResult> _read(
    LlmTurnSpec spec,
    Map<String, dynamic> arguments,
  ) async {
    final file = File(_scopedPath(spec, arguments['path'] as String));
    final content = await file.readAsString();
    return OpenAiToolResult(
      content: content.length > 120000
          ? '${content.substring(0, 120000)}\n[truncated]'
          : content,
    );
  }

  Future<OpenAiToolResult> _glob(
    LlmTurnSpec spec,
    Map<String, dynamic> arguments,
  ) async {
    final pattern = arguments['pattern'] as String;
    final matcher = _globRegex(pattern);
    final files = <String>[];
    await for (final entity in Directory(
      spec.workingDirectory,
    ).list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = path.relative(entity.path, from: spec.workingDirectory);
      if (matcher.hasMatch(relative)) files.add(relative);
      if (files.length >= 5000) break;
    }
    return OpenAiToolResult(content: files.join('\n'));
  }

  Future<OpenAiToolResult> _grep(
    LlmTurnSpec spec,
    Map<String, dynamic> arguments,
  ) async {
    final target = _scopedPath(
      spec,
      arguments['path'] as String? ?? spec.workingDirectory,
    );
    final regex = RegExp(arguments['pattern'] as String);
    final entities = FileSystemEntity.isFileSync(target)
        ? <FileSystemEntity>[File(target)]
        : await Directory(
            target,
          ).list(recursive: true, followLinks: false).toList();
    final matches = <String>[];
    for (final entity in entities.whereType<File>()) {
      try {
        final lines = await entity.readAsLines();
        for (var index = 0; index < lines.length; index++) {
          if (regex.hasMatch(lines[index])) {
            matches.add(
              '${path.relative(entity.path, from: spec.workingDirectory)}:${index + 1}:${lines[index]}',
            );
          }
          if (matches.length >= 1000) break;
        }
      } catch (_) {
        continue;
      }
      if (matches.length >= 1000) break;
    }
    return OpenAiToolResult(content: matches.join('\n'));
  }

  Future<OpenAiToolResult> _write(
    LlmTurnSpec spec,
    Map<String, dynamic> arguments,
  ) async {
    final file = File(_scopedPath(spec, arguments['path'] as String));
    await file.parent.create(recursive: true);
    await file.writeAsString(arguments['content'] as String);
    return OpenAiToolResult(
      content: jsonEncode({'ok': true, 'path': file.path}),
    );
  }

  Future<OpenAiToolResult> _edit(
    LlmTurnSpec spec,
    Map<String, dynamic> arguments,
  ) async {
    final file = File(_scopedPath(spec, arguments['path'] as String));
    final content = await file.readAsString();
    final oldText = arguments['old_text'] as String;
    final occurrences = oldText.isEmpty
        ? 0
        : oldText.allMatches(content).length;
    if (occurrences != 1) {
      return OpenAiToolResult(
        content: jsonEncode({
          'ok': false,
          'error':
              'old_text debe aparecer exactamente una vez; aparece $occurrences.',
        }),
        isError: true,
      );
    }
    await file.writeAsString(
      content.replaceFirst(oldText, arguments['new_text'] as String),
    );
    return OpenAiToolResult(
      content: jsonEncode({'ok': true, 'path': file.path}),
    );
  }

  Future<OpenAiToolResult> _bash(
    LlmTurnSpec spec,
    Map<String, dynamic> arguments,
  ) async {
    final result = await Process.run(
      '/bin/sh',
      ['-lc', arguments['command'] as String],
      workingDirectory: spec.workingDirectory,
    ).timeout(const Duration(seconds: 120));
    return OpenAiToolResult(
      content: jsonEncode({
        'ok': result.exitCode == 0,
        'exitCode': result.exitCode,
        'stdout': '${result.stdout}',
        'stderr': '${result.stderr}',
      }),
      isError: result.exitCode != 0,
    );
  }

  String _scopedPath(LlmTurnSpec spec, String requested) {
    final root = path.normalize(path.absolute(spec.workingDirectory));
    final resolved = path.normalize(
      path.isAbsolute(requested) ? requested : path.join(root, requested),
    );
    if (spec.fullFileSystemAccess) return resolved;

    // A lexical `..` check is not enough: `workspace/link -> /private` would
    // otherwise let Read/Edit/Write escape through a symlink. Resolve the
    // nearest existing ancestor too, which covers files that Write has not
    // created yet.
    final canonicalRoot = Directory(root).resolveSymbolicLinksSync();
    final canonicalTarget = _canonicalCandidate(resolved);
    if (canonicalTarget != canonicalRoot &&
        !path.isWithin(canonicalRoot, canonicalTarget)) {
      throw StateError('Ruta fuera del workspace: $requested');
    }
    return canonicalTarget;
  }

  @override
  Future<void> close() async {
    for (final connection in _connections) {
      await connection.close();
    }
    await _workspace?.dispose();
  }
}

String _canonicalCandidate(String candidate) {
  var existing = candidate;
  final missingSegments = <String>[];
  while (FileSystemEntity.typeSync(existing, followLinks: true) ==
      FileSystemEntityType.notFound) {
    final parent = path.dirname(existing);
    if (parent == existing) break;
    missingSegments.insert(0, path.basename(existing));
    existing = parent;
  }
  final type = FileSystemEntity.typeSync(existing, followLinks: true);
  final canonicalBase = type == FileSystemEntityType.directory
      ? Directory(existing).resolveSymbolicLinksSync()
      : File(existing).resolveSymbolicLinksSync();
  return path.normalize(path.joinAll([canonicalBase, ...missingSegments]));
}

String _openAiFunctionName(String raw) {
  final safe = raw.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  if (safe.length <= 64) return safe;
  final fingerprint = raw.hashCode.toUnsigned(32).toRadixString(16);
  return '${safe.substring(0, 55)}_$fingerprint';
}

Map<String, dynamic> _stringSchema(String description) => {
  'type': 'string',
  'description': description,
};

RegExp _globRegex(String pattern) {
  final buffer = StringBuffer('^');
  for (var index = 0; index < pattern.length; index++) {
    final char = pattern[index];
    if (char == '*') {
      final doubleStar =
          index + 1 < pattern.length && pattern[index + 1] == '*';
      buffer.write(doubleStar ? '.*' : '[^/]*');
      if (doubleStar) index++;
    } else if (char == '?') {
      buffer.write('[^/]');
    } else {
      buffer.write(RegExp.escape(char));
    }
  }
  buffer.write(r'$');
  return RegExp(buffer.toString());
}

class _ToolBinding {
  const _ToolBinding(this.definition, this.execute);

  final OpenAiFunctionDefinition definition;
  final Future<OpenAiToolResult> Function(Map<String, dynamic>) execute;
}

class _McpTool {
  const _McpTool({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;

  factory _McpTool.fromJson(Map<String, dynamic> json) => _McpTool(
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    inputSchema:
        (json['inputSchema'] as Map?)?.cast<String, dynamic>() ??
        const {'type': 'object', 'properties': <String, dynamic>{}},
  );
}

abstract class _McpConnection {
  Future<List<_McpTool>> initializeAndList();
  Future<OpenAiToolResult> call(String name, Map<String, dynamic> arguments);
  Future<void> close();
}

class _HttpMcpConnection implements _McpConnection {
  _HttpMcpConnection(this.name, this.config);

  final String name;
  final Map<String, dynamic> config;
  final http.Client _client = http.Client();
  String? _sessionId;
  int _id = 0;

  @override
  Future<List<_McpTool>> initializeAndList() async {
    await _request('initialize', {
      'protocolVersion': '2025-06-18',
      'capabilities': <String, dynamic>{},
      'clientInfo': {'name': 'keel-openai-compatible', 'version': '1.0.0'},
    });
    await _notify('notifications/initialized');
    final result = await _request('tools/list', const {});
    return [
      for (final raw in result['tools'] as List? ?? const [])
        if (raw is Map) _McpTool.fromJson(raw.cast<String, dynamic>()),
    ];
  }

  @override
  Future<OpenAiToolResult> call(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    final result = await _request('tools/call', {
      'name': name,
      'arguments': arguments,
    });
    final text = [
      for (final content in result['content'] as List? ?? const [])
        if (content is Map && content['text'] is String)
          content['text'] as String,
    ].join('\n');
    return OpenAiToolResult(
      content: text.isEmpty ? jsonEncode(result) : text,
      isError: result['isError'] as bool? ?? false,
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    Map<String, dynamic> params,
  ) async {
    final response = await _post({
      'jsonrpc': '2.0',
      'id': ++_id,
      'method': method,
      'params': params,
    });
    final error = response['error'];
    if (error != null) throw StateError('$name: $error');
    return (response['result'] as Map?)?.cast<String, dynamic>() ?? const {};
  }

  Future<void> _notify(String method) async {
    await _post({'jsonrpc': '2.0', 'method': method});
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    final uri = Uri.parse(config['url'] as String);
    final request = http.Request('POST', uri)
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/event-stream',
        ...((config['headers'] as Map?)?.cast<String, String>() ?? const {}),
        'Mcp-Session-Id': ?_sessionId,
      })
      ..body = jsonEncode(body);
    final streamed = await _client.send(request);
    _sessionId ??= streamed.headers['mcp-session-id'];
    final responseBody = await streamed.stream.bytesToString();
    if (streamed.statusCode >= HttpStatus.badRequest) {
      final detail = responseBody.trim();
      throw HttpException(
        'HTTP ${streamed.statusCode}'
        '${detail.isEmpty ? '' : ': $detail'}',
        uri: uri,
      );
    }
    if (streamed.statusCode == 202 || responseBody.trim().isEmpty) {
      return const {};
    }
    final payload = responseBody
        .split('\n')
        .map((line) => line.trim())
        .firstWhere(
          (line) => line.startsWith('data:'),
          orElse: () => responseBody,
        )
        .replaceFirst(RegExp(r'^data:\s*'), '');
    return (jsonDecode(payload) as Map).cast<String, dynamic>();
  }

  @override
  Future<void> close() async => _client.close();
}

class _StdioMcpConnection implements _McpConnection {
  _StdioMcpConnection(this.name, this.config);

  final String name;
  final Map<String, dynamic> config;
  Process? _process;
  StreamIterator<String>? _lines;
  int _id = 0;

  @override
  Future<List<_McpTool>> initializeAndList() async {
    _process = await Process.start(
      config['command'] as String,
      (config['args'] as List? ?? const []).cast<String>(),
      environment: {
        ...Platform.environment,
        ...((config['env'] as Map?)?.cast<String, String>() ?? const {}),
      },
    );
    _lines = StreamIterator(
      _process!.stdout.transform(utf8.decoder).transform(const LineSplitter()),
    );
    await _request('initialize', {
      'protocolVersion': '2025-06-18',
      'capabilities': <String, dynamic>{},
      'clientInfo': {'name': 'keel-openai-compatible', 'version': '1.0.0'},
    });
    _send({'jsonrpc': '2.0', 'method': 'notifications/initialized'});
    final result = await _request('tools/list', const {});
    return [
      for (final raw in result['tools'] as List? ?? const [])
        if (raw is Map) _McpTool.fromJson(raw.cast<String, dynamic>()),
    ];
  }

  @override
  Future<OpenAiToolResult> call(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    final result = await _request('tools/call', {
      'name': name,
      'arguments': arguments,
    });
    final text = [
      for (final content in result['content'] as List? ?? const [])
        if (content is Map && content['text'] is String)
          content['text'] as String,
    ].join('\n');
    return OpenAiToolResult(
      content: text.isEmpty ? jsonEncode(result) : text,
      isError: result['isError'] as bool? ?? false,
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    Map<String, dynamic> params,
  ) async {
    final id = ++_id;
    _send({'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params});
    final lines = _lines!;
    while (await lines.moveNext()) {
      final decoded = jsonDecode(lines.current);
      if (decoded is! Map || decoded['id'] != id) continue;
      if (decoded['error'] != null) {
        throw StateError('$name: ${decoded['error']}');
      }
      return (decoded['result'] as Map?)?.cast<String, dynamic>() ?? const {};
    }
    throw StateError('$name cerró antes de responder $method');
  }

  void _send(Map<String, dynamic> message) {
    _process!.stdin.writeln(jsonEncode(message));
  }

  @override
  Future<void> close() async {
    await _process?.stdin.close();
    _process?.kill();
    await _lines?.cancel();
  }
}
