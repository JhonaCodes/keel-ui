library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';

class JobsApiState {
  final int? port;
  final String token;

  const JobsApiState({this.port, this.token = ''});

  bool get running => port != null;

  JobsApiState copyWith({int? port, String? token}) {
    return JobsApiState(port: port ?? this.port, token: token ?? this.token);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JobsApiState &&
          runtimeType == other.runtimeType &&
          port == other.port &&
          token == other.token;

  @override
  int get hashCode => Object.hash(port, token);

  // Token deliberately omitted — state objects get logged.
  @override
  String toString() => 'JobsApiState(port: $port)';
}

/// Local HTTP API for EXTERNAL schedulers (cron, keel, scripts): open a
/// session in a project and check its status, over loopback with a persisted
/// Bearer token. This is the plug for scheduled work — the scheduling
/// itself lives outside the app.
///
/// - `POST /projects/<name>/sessions` body `{"prompt": "..."}` → creates a
///   fresh session in that project and sends the prompt into it.
/// - `GET  /sessions/<id>` → `{status, isRunning, costUsd, messages}`.
class JobsApiViewModel extends ViewModel<JobsApiState> {
  JobsApiViewModel() : super(const JobsApiState());

  static const _dbKey = 'jobs_api';

  /// Fixed preferred port so external cron entries survive restarts; falls
  /// back to an ephemeral one if something else took it.
  static const _preferredPort = 47821;

  HttpServer? _server;

  @override
  void init() {
    // Guarded like every catalog VM: mounting the settings panel triggers
    // reinitializeWithContext() → a second init(), and wiping {port, token}
    // here would 401 every external request until restart.
    if (_server == null) updateSilently(const JobsApiState());
  }

  /// Starts the API once (call from `main()` after the database is up).
  Future<void> start() async {
    if (_server != null) return;

    var token = (await LocalDatabase.get(_dbKey))?['token'] as String? ?? '';
    if (token.isEmpty) {
      token = _generateToken();
      await LocalDatabase.put(_dbKey, {'id': _dbKey, 'token': token});
    }

    HttpServer server;
    try {
      server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        _preferredPort,
      );
    } on SocketException {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    }
    _server = server;
    updateState(JobsApiState(port: server.port, token: token));
    Log.i('Jobs API listening on 127.0.0.1:${server.port}');

    server.listen((request) async {
      try {
        await _handle(request);
      } catch (error, stackTrace) {
        Log.e('Jobs API request failed', error: error, stackTrace: stackTrace);
        _respond(request, HttpStatus.internalServerError, {
          'error': 'internal',
        });
      }
    });
  }

  /// Invalidates every existing cron entry's credential.
  Future<void> regenerateToken() async {
    final token = _generateToken();
    await LocalDatabase.put(_dbKey, {'id': _dbKey, 'token': token});
    updateState(data.copyWith(token: token));
  }

  Future<void> _handle(HttpRequest request) async {
    if (request.headers.value('authorization') != 'Bearer ${data.token}') {
      _respond(request, HttpStatus.unauthorized, {'error': 'unauthorized'});
      return;
    }

    final segments = request.uri.pathSegments;
    final projects = ProjectsService.instance.notifier;

    // POST /projects/<name>/sessions
    //
    // `/stations/<name>/tasks` sigue contestando: es la única superficie
    // HTTP de la app, y un script de afuera no tiene por qué enterarse de
    // que acá adentro cambiamos las palabras. Queda como alias obsoleto.
    final isSessionPost =
        (segments.length == 3) &&
        ((segments[0] == 'projects' && segments[2] == 'sessions') ||
            (segments[0] == 'stations' && segments[2] == 'tasks'));
    if (request.method == 'POST' && isSessionPost) {
      final project = projects.data.projects
          .where((entry) => entry.name == segments[1])
          .firstOrNull;
      if (project == null) {
        _respond(request, HttpStatus.notFound, {'error': 'project not found'});
        return;
      }
      if (project.workingDirectory.trim().isEmpty) {
        _respond(request, HttpStatus.conflict, {
          'error': 'project has no working directory yet',
        });
        return;
      }

      final body = await utf8.decoder.bind(request).join();
      final String prompt;
      try {
        prompt = (jsonDecode(body) as Map<String, dynamic>)['prompt'] as String;
      } catch (_) {
        _respond(request, HttpStatus.badRequest, {
          'error': 'body must be {"prompt": "..."}',
        });
        return;
      }
      if (prompt.trim().isEmpty) {
        _respond(request, HttpStatus.badRequest, {'error': 'empty prompt'});
        return;
      }

      projects.createSession(project.id);
      final session = projects.data.projects
          .firstWhere((entry) => entry.id == project.id)
          .activeSession;
      if (session == null) {
        _respond(request, HttpStatus.internalServerError, {
          'error': 'session not created',
        });
        return;
      }
      // Fire-and-forget: the turn outlives the HTTP request on purpose.
      unawaited(projects.sendToChannel(project.id, prompt));
      _respond(request, HttpStatus.accepted, {
        'sessionId': session.id,
        'project': project.name,
      });
      return;
    }

    // GET /sessions/<id> — `/tasks/<id>` sigue contestando por lo mismo que
    // la ruta de alta: afuera hay scripts que no tienen por qué enterarse de
    // que acá adentro cambiamos las palabras.
    if (request.method == 'GET' &&
        segments.length == 2 &&
        (segments[0] == 'sessions' || segments[0] == 'tasks')) {
      for (final project in projects.data.projects) {
        final session = project.sessions
            .where((entry) => entry.id == segments[1])
            .firstOrNull;
        if (session != null) {
          _respond(request, HttpStatus.ok, {
            'sessionId': session.id,
            'project': project.name,
            'status': session.status.name,
            'isRunning': session.isRunning,
            'costUsd': session.costUsd,
            'messages': session.messages.length,
          });
          return;
        }
      }
      _respond(request, HttpStatus.notFound, {'error': 'session not found'});
      return;
    }

    _respond(request, HttpStatus.notFound, {'error': 'unknown endpoint'});
  }

  void _respond(HttpRequest request, int status, Map<String, dynamic> body) {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    unawaited(request.response.close());
  }

  String _generateToken() {
    final random = Random.secure();
    return List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

mixin JobsApiService {
  static final ReactiveNotifier<JobsApiViewModel> instance =
      ReactiveNotifier<JobsApiViewModel>(() => JobsApiViewModel());
}
