import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keel_core/engine/core_engine.dart';
import 'package:keel_core/integrations/node_keel_ai/node_keel_ai.dart';
import 'package:keel_core/integrations/node_link/node_link.dart';
import 'package:keel_core/protocol/keel_protocol.dart';
import 'package:result_controller/result_controller.dart';

import 'package:keel_ui/src/integrations/keel_node/keel_node.dart';

typedef _TaskEnd = ({bool failed, Map<String, Object?> result});

/// keel-api's task queue on a local port: it serves the queued tasks once
/// and keeps how each task ended (`PUT tasks/{id}/fail|done`).
final class _FakeKeelApi {
  late final HttpServer _server;

  /// What the next `GET tasks/pending` serves, once.
  List<Map<String, Object?>> pending = [];

  /// Task id → the `result_json` it ended with, and whether it failed.
  final Map<String, _TaskEnd> ended = {};

  final Map<String, Completer<_TaskEnd>> _endings = {};

  /// How task [id] ends, once it does: a task answered off the queue ends
  /// after the poll that took it.
  Future<_TaskEnd> ending(String id) =>
      _endings.putIfAbsent(id, Completer<_TaskEnd>.new).future;

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
      _TaskEnd? end;
      if (request.method == 'PUT' &&
          segments.length == 3 &&
          segments.first == 'tasks' &&
          (segments.last == 'fail' || segments.last == 'done')) {
        end = (
          failed: segments.last == 'fail',
          result: (jsonDecode('${body['result_json']}') as Map)
              .cast<String, Object?>(),
        );
        ended[segments[1]] = end;
      }
      final Object answer = path == 'tasks/pending'
          ? _takePending()
          : const <String, Object?>{};
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(answer));
      await request.response.close();
      // Once answered, so a test that ends on it never cuts the call short.
      if (end != null) {
        final waiting = _endings.putIfAbsent(segments[1], Completer.new);
        if (!waiting.isCompleted) waiting.complete(end);
      }
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
      handlers: DesktopNodeRuntime.handlersFor(() => null),
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

  test('a message the app sends to Keel AI on this PC is answered by it, '
      'not refused', () async {
    final api = _FakeKeelApi();
    await api.start();
    final dir = await Directory.systemTemp.createTemp('keel_node_');
    addTearDown(() async {
      await api.stop();
      await dir.delete(recursive: true);
    });

    api.pending = [
      {
        'id': 'k-0',
        'type': 'keelai.send',
        'source': 'app',
        'payload_json': jsonEncode({
          'text': '¿Cómo va keel-ui?',
          'conversation_id': 'c-1',
        }),
      },
    ];
    final keelAi = _AnsweringKeelAi('keel-ui está al día.');
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
      handlers: DesktopNodeRuntime.handlersFor(() => keelAi),
    );

    await link.pollOnce();
    final end = await api.ending('k-0').timeout(const Duration(seconds: 5));

    expect(end.failed, isFalse, reason: 'keelai.send must not be refused');
    expect(end.result, {
      'conversation_id': 'c-1',
      'reply': 'keel-ui está al día.',
    });
    expect(keelAi.asked, ['¿Cómo va keel-ui?']);
    expect(ran, isEmpty, reason: 'Keel AI answers without a session command');
  });
}

/// Keel AI answering every message with [reply], noting what it was asked.
final class _AnsweringKeelAi implements NodeKeelAiChat {
  _AnsweringKeelAi(this.reply);

  final String reply;
  final List<String> asked = [];

  @override
  Future<Result<({String conversationId, String reply}), String>> ask(
    String text, {
    required String askId,
    String? conversationId,
    bool freshConversation = false,
  }) async {
    asked.add(text);
    return Ok((conversationId: conversationId ?? 'new', reply: reply));
  }

  @override
  void cancel([String? askId]) {}

  @override
  Result<
    ({NodeKeelAiConversation open, List<NodeKeelAiConversation> all}),
    String
  >
  openConversation(String? id) => Err('not opened in this test');

  @override
  Result<String, String> startConversation({String? agent}) =>
      Err('not started in this test');
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
