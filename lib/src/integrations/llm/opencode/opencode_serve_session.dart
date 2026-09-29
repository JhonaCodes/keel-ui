import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:logger_rs/logger_rs.dart';

import 'package:keel_ui/src/core/services/cli_turn_contract.dart';
import 'package:keel_ui/src/integrations/llm/llm.dart';
import 'package:keel_ui/src/integrations/llm/opencode/opencode_config.dart';

/// One `opencode serve` kept alive for a conversation, driven over its HTTP
/// API. Verified against OpenCode 1.18.29.
///
/// Why the server and not `opencode run`: a non-interactive run rejects
/// every permission `ask` on its own, so nothing could ever wait for the
/// person. The server publishes `permission.asked` on its event stream and
/// takes the answer on `/permission/{id}/reply`; here that answer comes from
/// Keel's gate, the same card claude and codex use.
///
/// A turn is `prompt_async` plus the `/event` stream until the session goes
/// idle. Tool names are translated to Keel's (`bash` → `Bash`, `edit` →
/// `Edit` with `file_path`) so activity, diffs and grants read the same for
/// every provider.
class OpenCodeServeSession implements LlmLiveSession {
  OpenCodeServeSession._(
    this._process,
    this._workspace,
    this._baseUri, {
    required String password,
    required LlmTurnSpec spec,
  }) : _authorization =
           'Basic ${base64Encode(utf8.encode('opencode:$password'))}',
       _spec = spec,
       _sessionId = spec.sessionId;

  final Process _process;
  final Directory _workspace;
  final Uri _baseUri;
  final String _authorization;
  final LlmTurnSpec _spec;
  final HttpClient _http = HttpClient();
  final StreamController<LlmEvent> _events = StreamController<LlmEvent>();

  String? _sessionId;
  bool _turnActive = false;
  bool _killed = false;
  final Set<String> _assistantMessages = {};
  final Set<String> _emittedParts = {};
  final Set<String> _runningCalls = {};

  /// This conversation's session and the child sessions its subagents
  /// (`task`) open: their permission requests are this turn's too.
  final Set<String> _ownSessions = {};

  /// Subagent tasks allowed and not finished yet.
  int _runningTasks = 0;
  _TurnUsage _usage = const _TurnUsage();

  static const _startTimeout = Duration(seconds: 30);

  static Future<LlmLiveSession> start(
    LlmTurnSpec spec, {
    required String userPath,
    void Function(int pid)? onPidKnown,
  }) async {
    final config = buildOpenCodeConfig(
      mcpConfigJson: spec.mcpConfig,
      hasGate: spec.permissionGateUrl != null,
      readOnly: spec.sandboxReadOnly || spec.planMode,
      fullDiskAccess: spec.fullFileSystemAccess,
    );
    // Files, never inline arguments: an argument is readable with `ps`.
    final workspace = await Directory.systemTemp.createTemp('keel_opencode_');
    final configFile = File('${workspace.path}/opencode.json');
    await configFile.writeAsString(config.configJson);
    final password = _randomToken();

    final Process process;
    try {
      process = await Process.start(
        'opencode',
        const ['serve', '--port', '0', '--hostname', '127.0.0.1', '--pure'],
        workingDirectory: spec.workingDirectory,
        environment: {
          'PATH': userPath,
          // OpenCode reads PWD before the process's working directory.
          'PWD': spec.workingDirectory,
          'OPENCODE_CONFIG': configFile.path,
          'OPENCODE_SERVER_PASSWORD': password,
          ...config.environment,
        },
        runInShell: true,
      );
    } catch (error) {
      await workspace.delete(recursive: true);
      rethrow;
    }
    onPidKnown?.call(process.pid);

    final listening = Completer<Uri>();
    final stderrTail = StringBuffer();
    process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(
      (line) {
        final match = RegExp(r'listening on (http://\S+)').firstMatch(line);
        if (match != null && !listening.isCompleted) {
          listening.complete(Uri.parse(match.group(1)!));
        }
      },
      onError: (Object error) => Log.w('stdout de opencode ilegible: $error'),
    );
    process.stderr.transform(utf8.decoder).listen(
      (chunk) {
        stderrTail.write(chunk);
        if (stderrTail.length > 4000) {
          final text = stderrTail.toString();
          stderrTail
            ..clear()
            ..write(text.substring(text.length - 4000));
        }
      },
      onError: (Object error) => Log.w('stderr de opencode ilegible: $error'),
    );
    unawaited(
      process.exitCode.then((code) {
        if (!listening.isCompleted) {
          listening.completeError(
            StateError(
              'opencode serve terminó con código $code antes de escuchar: '
              '${stderrTail.toString().trim()}',
            ),
          );
        }
      }),
    );

    final Uri baseUri;
    try {
      baseUri = await listening.future.timeout(_startTimeout);
    } catch (error) {
      process.kill();
      await workspace.delete(recursive: true);
      rethrow;
    }

    final session = OpenCodeServeSession._(
      process,
      workspace,
      baseUri,
      password: password,
      spec: spec,
    );
    await session._listen();
    return session;
  }

  @override
  Stream<LlmEvent> get events => _events.stream;

  @override
  void send(String prompt) {
    _turnActive = true;
    _usage = const _TurnUsage();
    unawaited(_prompt(prompt));
  }

  @override
  void kill() {
    _killed = true;
    final sessionId = _sessionId;
    if (sessionId != null) {
      unawaited(_abort(sessionId));
    }
    _process.kill();
  }

  @override
  Future<void> close() async => _process.kill();

  Future<void> _abort(String sessionId) async {
    try {
      await _post('/session/$sessionId/abort', const {});
    } catch (error) {
      Log.w('No se pudo abortar opencode: $error');
    }
  }

  Future<void> _prompt(String prompt) async {
    try {
      final sessionId = _sessionId ??= await _createSession();
      _ownSessions.add(sessionId);
      _events.add({'type': 'sessionStarted', 'sessionId': sessionId});
      final model = _spec.model;
      final slash = model.indexOf('/');
      await _post('/session/$sessionId/prompt_async', {
        if (slash > 0)
          'model': {
            'providerID': model.substring(0, slash),
            'modelID': model.substring(slash + 1),
          },
        if (_spec.additionalSystemPrompt case final system?
            when system.isNotEmpty)
          'system': system,
        if (_spec.effort.isNotEmpty) 'variant': _spec.effort,
        'parts': [
          {'type': 'text', 'text': prompt},
        ],
      });
    } catch (error) {
      _fail('No se pudo enviar el turno a opencode: $error');
    }
  }

  Future<String> _createSession() async {
    final created = await _post('/session', {'title': 'Keel'});
    final id = (created as Map?)?['id'];
    if (id is! String) throw StateError('opencode no devolvió una sesión');
    return id;
  }

  Future<void> _listen() async {
    final request = await _http.getUrl(_uri('/event'));
    request.headers.set(HttpHeaders.authorizationHeader, _authorization);
    request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
    final response = await request.close();
    final data = StringBuffer();
    response
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (line.startsWith('data:')) {
              data.write(line.substring(5).trimLeft());
              return;
            }
            if (line.isNotEmpty || data.isEmpty) return;
            final raw = data.toString();
            data.clear();
            try {
              _onEvent(jsonDecode(raw) as Map<String, dynamic>);
            } catch (error) {
              Log.w('Evento de opencode ilegible: $error');
            }
          },
          onDone: () => unawaited(_onExit()),
          onError: (Object error) {
            Log.w('Se cortó el stream de eventos de opencode: $error');
            unawaited(_onExit());
          },
        );
  }

  void _onEvent(Map<String, dynamic> event) {
    final properties =
        (event['properties'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    switch (event['type']) {
      case 'session.created' || 'session.updated':
        final info = (properties['info'] as Map?)?.cast<String, dynamic>();
        if (_ownSessions.contains(info?['parentID'])) {
          _ownSessions.add('${info?['id']}');
        }
      case 'message.updated':
        final info = (properties['info'] as Map?)?.cast<String, dynamic>();
        if (info?['sessionID'] == _sessionId && info?['role'] == 'assistant') {
          _assistantMessages.add('${info?['id']}');
          if (info?['modelID'] case final String model) {
            _usage = _usage.copyWith(model: model);
          }
        }
      case 'message.part.updated':
        final part = (properties['part'] as Map?)?.cast<String, dynamic>();
        if (part == null || part['sessionID'] != _sessionId) return;
        if (!_assistantMessages.contains('${part['messageID']}')) return;
        _onPart(part);
      case 'permission.asked':
        if (!_ownSessions.contains(properties['sessionID'])) return;
        unawaited(_answerPermission(properties));
      case 'session.error':
        if (properties['sessionID'] != null &&
            properties['sessionID'] != _sessionId) {
          return;
        }
        final error = (properties['error'] as Map?)?.cast<String, dynamic>();
        final message =
            (error?['data'] as Map?)?['message'] ?? error?['name'] ?? 'error';
        if (_turnActive) {
          _events.add({'type': 'failure', 'message': 'opencode: $message'});
        }
      case 'session.idle':
        if (properties['sessionID'] == _sessionId) _endTurn();
    }
  }

  void _onPart(Map<String, dynamic> part) {
    final id = '${part['id']}';
    final finished = (part['time'] as Map?)?['end'] != null;
    switch (part['type']) {
      case 'text':
        final text = '${part['text'] ?? ''}';
        if (finished && text.trim().isNotEmpty && _emittedParts.add(id)) {
          _events.add({'type': 'assistantText', 'text': text});
        }
      case 'reasoning':
        final text = '${part['text'] ?? ''}';
        if (finished && text.trim().isNotEmpty && _emittedParts.add(id)) {
          _events.add({'type': 'reasoningChunk', 'text': text});
        }
      case 'tool':
        final state = (part['state'] as Map?)?.cast<String, dynamic>();
        final callId = '${part['callID']}';
        final tool = '${part['tool']}';
        switch (state?['status']) {
          case 'running':
            if (_runningCalls.add(callId)) {
              _events.add({
                'type': 'toolUse',
                'name': _keelToolName(tool),
                'input': _keelToolInput(state?['input']),
              });
            }
          case 'completed' when tool == 'task':
            _finishTask();
          case 'error':
            if (tool == 'task') _finishTask();
            _events.add({
              'type': 'notice',
              'message':
                  'La tool ${_keelToolName(tool)} falló: '
                  '${state?['error'] ?? 'sin detalle'}',
            });
        }
      case 'step-finish':
        _usage = _usage.add(part);
    }
  }

  /// Asks Keel's gate, then answers OpenCode. With no gate, what reaches
  /// here (only what the config left on `ask`) is refused: nobody could
  /// have said yes.
  Future<void> _answerPermission(Map<String, dynamic> request) async {
    final id = '${request['id']}';
    if (request['permission'] == 'task') {
      await _reply(id, _startTask() ? 'once' : 'reject');
      return;
    }
    var reply = 'reject';
    final gateUrl = _spec.permissionGateUrl;
    if (gateUrl != null) {
      try {
        final decision = await _askGate(gateUrl, request);
        reply = decision ? 'once' : 'reject';
      } catch (error) {
        Log.w('El gate de Keel no contestó a opencode: $error');
      }
    }
    await _reply(id, reply);
  }

  Future<void> _reply(String id, String reply) async {
    try {
      await _post('/permission/$id/reply', {'reply': reply});
    } catch (error) {
      _fail('No se pudo contestar el permiso a opencode: $error');
    }
  }

  /// Room for one more subagent? Rejecting is what OpenCode relays to the
  /// model, which then does the work itself instead.
  bool _startTask() {
    if (_runningTasks >= SubagentLimits.maxParallel) return false;
    _runningTasks++;
    return true;
  }

  void _finishTask() {
    if (_runningTasks > 0) _runningTasks--;
  }

  Future<bool> _askGate(String gateUrl, Map<String, dynamic> request) async {
    final permission = '${request['permission']}';
    final metadata =
        (request['metadata'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final patterns = [
      for (final pattern in request['patterns'] as List? ?? const [])
        '$pattern',
    ];
    final (toolName, toolInput) = switch (permission) {
      'bash' => (
        'Bash',
        {'command': metadata['command'] ?? patterns.join(' ')},
      ),
      'edit' => (
        'Edit',
        {
          'file_path':
              metadata['filepath'] ??
              metadata['filePath'] ??
              patterns.firstOrNull ??
              '',
        },
      ),
      _ => (permission, {'path': patterns.join(', ')}),
    };
    final call = await _http.postUrl(Uri.parse(gateUrl));
    call.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${_spec.permissionGateToken ?? ''}',
    );
    _writeJson(call, {'tool_name': toolName, 'tool_input': toolInput});
    final response = await call.close();
    final body = await response.transform(utf8.decoder).join();
    final decoded = jsonDecode(body);
    return decoded is Map && decoded['decision'] == 'allow';
  }

  void _endTurn() {
    if (!_turnActive) return;
    _turnActive = false;
    _events
      ..add(_usage.toTurnCompleted())
      ..add({'type': 'turnEnded'});
  }

  void _fail(String message) {
    Log.e(message);
    if (!_turnActive) return;
    _events.add({'type': 'failure', 'message': message});
    _turnActive = false;
    _events.add({'type': 'turnEnded'});
  }

  bool _exited = false;

  Future<void> _onExit() async {
    if (_exited) return;
    _exited = true;
    if (_turnActive) {
      if (!_killed) {
        _events.add({
          'type': 'failure',
          'message': 'opencode se cerró a mitad del turno.',
        });
      }
      _turnActive = false;
      _events.add({'type': 'turnEnded'});
    }
    _process.kill();
    _http.close(force: true);
    try {
      await _workspace.delete(recursive: true);
    } on FileSystemException catch (error) {
      Log.w('No se pudo borrar el workspace de opencode: ${error.message}');
    }
    await _events.close();
  }

  Uri _uri(String path) => _baseUri.replace(
    path: path,
    queryParameters: {'directory': _spec.workingDirectory},
  );

  Future<Object?> _post(String path, Map<String, dynamic> body) async {
    final request = await _http.postUrl(_uri(path));
    request.headers.set(HttpHeaders.authorizationHeader, _authorization);
    _writeJson(request, body);
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode >= 400) {
      throw HttpException('HTTP ${response.statusCode}: $text');
    }
    return text.isEmpty ? null : jsonDecode(text);
  }

  /// With its length up front: a chunked body is not something every HTTP
  /// server reads.
  static void _writeJson(HttpClientRequest request, Map<String, dynamic> body) {
    final bytes = utf8.encode(jsonEncode(body));
    request.headers.contentType = ContentType.json;
    request.contentLength = bytes.length;
    request.add(bytes);
  }

  static String _randomToken() {
    final random = Random.secure();
    return List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static String _keelToolName(String tool) => switch (tool) {
    'bash' => 'Bash',
    'edit' || 'patch' || 'multiedit' => 'Edit',
    'write' => 'Write',
    'read' => 'Read',
    'glob' => 'Glob',
    'grep' => 'Grep',
    'list' => 'LS',
    'webfetch' => 'WebFetch',
    'websearch' => 'WebSearch',
    'task' => 'Task',
    'todowrite' => 'TodoWrite',
    _ => tool,
  };

  /// OpenCode's inputs are camelCase (`filePath`); Keel's file tracking and
  /// activity labels read claude's (`file_path`).
  static Map<String, dynamic>? _keelToolInput(Object? input) {
    if (input is! Map) return null;
    return {
      for (final entry in input.entries)
        switch ('${entry.key}') {
          'filePath' => 'file_path',
          'oldString' => 'old_string',
          'newString' => 'new_string',
          final key => key,
        }: entry.value,
    };
  }
}

/// What the turn's `step-finish` parts added up to.
class _TurnUsage {
  const _TurnUsage({
    this.input = 0,
    this.output = 0,
    this.cacheRead = 0,
    this.cacheWrite = 0,
    this.cost = 0,
    this.model = '',
  });

  final int input;
  final int output;
  final int cacheRead;
  final int cacheWrite;
  final double cost;
  final String model;

  _TurnUsage copyWith({String? model}) => _TurnUsage(
    input: input,
    output: output,
    cacheRead: cacheRead,
    cacheWrite: cacheWrite,
    cost: cost,
    model: model ?? this.model,
  );

  _TurnUsage add(Map<String, dynamic> step) {
    final tokens = (step['tokens'] as Map?)?.cast<String, dynamic>();
    final cache = (tokens?['cache'] as Map?)?.cast<String, dynamic>();
    int read(Object? value) => (value as num?)?.toInt() ?? 0;
    return _TurnUsage(
      input: input + read(tokens?['input']),
      output: output + read(tokens?['output']) + read(tokens?['reasoning']),
      cacheRead: cacheRead + read(cache?['read']),
      cacheWrite: cacheWrite + read(cache?['write']),
      cost: cost + ((step['cost'] as num?)?.toDouble() ?? 0),
      model: model,
    );
  }

  LlmEvent toTurnCompleted() => {
    'type': 'turnCompleted',
    'isError': false,
    'costUsd': cost,
    'costReported': true,
    'durationMs': 0,
    'model': model,
    'inputTokens': input,
    'outputTokens': output,
    'cacheReadTokens': cacheRead,
    'cacheCreationTokens': cacheWrite,
    'tokensReported': true,
  };
}
