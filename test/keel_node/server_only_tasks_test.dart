import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keel_core/engine/core_engine.dart';
import 'package:keel_core/integrations/node_link/node_link.dart';
import 'package:keel_core/protocol/keel_protocol.dart';

import 'package:keel_ui/src/integrations/keel_node/keel_node.dart';

/// keel-api's task queue on a local port: it serves the queued tasks once
/// and keeps how each task ended (`PUT tasks/{id}/fail|done`).
final class _FakeKeelApi {
  late final HttpServer _server;

  /// What the next `GET tasks/pending` serves, once.
  List<Map<String, Object?>> pending = [];

  /// Task id → the `result_json` it ended with, and whether it failed.
  final Map<String, ({bool failed, Map<String, Object?> result})> ended = {};

  Uri get base => Uri.parse('http://127.0.0.1:${_server.port}/v1/keel-bot/');

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((request) async {
      final text = await utf8.decodeStream(request);
      final body = text.isEmpty
          ? const <String, Object?>{}
          : (jsonDecode(text) as Map).cast<String, Object?>();
      final path = request.uri.path.replaceFirst('/v1/keel-bot/', '');
      final segments = path.split('/');
      if (request.method == 'PUT' &&
          segments.length == 3 &&
          segments.first == 'tasks' &&
          (segments.last == 'fail' || segments.last == 'done')) {
        ended[segments[1]] = (
          failed: segments.last == 'fail',
          result: (jsonDecode('${body['result_json']}') as Map)
              .cast<String, Object?>(),
        );
      }
      final Object answer = path == 'tasks/pending'
          ? _takePending()
          : const <String, Object?>{};
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(answer));
      await request.response.close();
    });
  }

  List<Map<String, Object?>> _takePending() {
    final taken = pending;
    pending = [];
    return taken;
  }

  Future<void> stop() => _server.close(force: true);
}

void main() {
  test('work only a keel-server runs fails at once on this PC with why, and '
      'never reaches its sessions', () async {
    final api = _FakeKeelApi();
    await api.start();
    final dir = await Directory.systemTemp.createTemp('keel_node_');
    addTearDown(() async {
      await api.stop();
      await dir.delete(recursive: true);
    });

    // Each kind keel-server runs and this PC does not. Some name a workflow
    // and a project: without a rejecter they would start a session here.
    const serverOnly = [
      'deploy.run',
      'job.run',
      'tool.run',
      'launch.app',
      'cloudflare.dns.propose',
      'keelai.send',
    ];
    api.pending = [
      for (final (index, type) in serverOnly.indexed)
        {
          'id': 't-$index',
          'type': type,
          'project': 'keel-ui',
          'source': 'app',
          'payload_json': jsonEncode({
            if (index.isEven) 'workflow': 'Deploy',
            'title': 'Ship it',
          }),
        },
    ];
    final ran = <KeelCommand>[];
    final link = NodeLink(
      client: HttpKeelApiClient(
        apiUrl: api.base,
        nodeId: 'mac-de-jhona-desktop',
        credentials: IssuedNodeToken(() => 'knt_test'),
      ),
      host: _RecordingHost(
        KeelUiNodeHost(
          engine: CoreEngine(),
          projection: () => const KeelProjection(),
        ),
        ran,
      ),
      statePath: '${dir.path}/tasks.json',
      handlers: DesktopNodeRuntime.handlers,
    );

    await link.pollOnce();

    for (final (index, type) in serverOnly.indexed) {
      final end = api.ended['t-$index'];
      expect(end?.failed, isTrue, reason: '$type must fail');
      expect(
        end?.result['error'],
        'Este tipo de tarea solo corre en un servidor keel-server.',
        reason: '$type must say why',
      );
    }
    expect(
      ran,
      isEmpty,
      reason: 'no server-only task may run a command on this PC',
    );
  });
}

/// keel-ui's host, noting every command the link hands it.
final class _RecordingHost extends NodeLinkHost {
  _RecordingHost(this._host, this._ran);

  final KeelUiNodeHost _host;
  final List<KeelCommand> _ran;

  @override
  String get label => _host.label;

  @override
  KeelProjection get projection => _host.projection;

  @override
  String resolveProject(String name) => _host.resolveProject(name);

  @override
  Future<NodeRunResult> run(KeelCommand command) {
    _ran.add(command);
    return _host.run(command);
  }
}
