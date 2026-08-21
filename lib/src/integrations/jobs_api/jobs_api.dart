library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/stations/viewmodel/stations_viewmodel.dart';

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
/// task in a station and check its status, over loopback with a persisted
/// Bearer token. This is the plug for scheduled work — the scheduling
/// itself lives outside the app.
///
/// - `POST /stations/<name>/tasks` body `{"prompt": "..."}` → creates a
///   fresh task in that station and sends the prompt into it.
/// - `GET  /tasks/<id>` → `{status, isRunning, costUsd, messages}`.
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

    var token =
        (await LocalDatabase.get(_dbKey))?['token'] as String? ?? '';
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
    final stations = StationsService.instance.notifier;

    // POST /stations/<name>/tasks
    if (request.method == 'POST' &&
        segments.length == 3 &&
        segments[0] == 'stations' &&
        segments[2] == 'tasks') {
      final station = stations.data.stations
          .where((entry) => entry.name == segments[1])
          .firstOrNull;
      if (station == null) {
        _respond(request, HttpStatus.notFound, {'error': 'station not found'});
        return;
      }
      if (station.workingDirectory.trim().isEmpty) {
        _respond(request, HttpStatus.conflict, {
          'error': 'station has no working directory yet',
        });
        return;
      }

      final body = await utf8.decoder.bind(request).join();
      final String prompt;
      try {
        prompt =
            (jsonDecode(body) as Map<String, dynamic>)['prompt'] as String;
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

      stations.createTask(station.id);
      final task = stations.data.stations
          .firstWhere((entry) => entry.id == station.id)
          .activeTask;
      if (task == null) {
        _respond(request, HttpStatus.internalServerError, {
          'error': 'task not created',
        });
        return;
      }
      // Fire-and-forget: the turn outlives the HTTP request on purpose.
      unawaited(stations.sendToChannel(station.id, prompt));
      _respond(request, HttpStatus.accepted, {
        'taskId': task.id,
        'station': station.name,
      });
      return;
    }

    // GET /tasks/<id>
    if (request.method == 'GET' &&
        segments.length == 2 &&
        segments[0] == 'tasks') {
      for (final station in stations.data.stations) {
        final task = station.tasks
            .where((entry) => entry.id == segments[1])
            .firstOrNull;
        if (task != null) {
          _respond(request, HttpStatus.ok, {
            'taskId': task.id,
            'station': station.name,
            'status': task.status.name,
            'isRunning': task.isRunning,
            'costUsd': task.costUsd,
            'messages': task.messages.length,
          });
          return;
        }
      }
      _respond(request, HttpStatus.notFound, {'error': 'task not found'});
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
