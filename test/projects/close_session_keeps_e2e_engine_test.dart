import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keel_e2e_panel/keel_e2e_panel.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_core/core/store/keel_store.dart';
import 'package:keel_ui/src/core/services/flutter_local_db_store.dart';
import 'package:keel_core/modules/projects/model/project.dart';
import 'package:keel_core/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/model/e2e_device_workflow.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';
import 'package:keel_core/core/host/keel_host.dart';
import 'package:keel_ui/src/core/host/keel_host_impl.dart';

final _epoch = DateTime(2026, 10, 2);

/// Caso real (tablet, run r_4, 2026-10-02): cerrar otra sesión que usaba
/// E2E apagó el motor entero a mitad de una prueba — el agente recibió
/// ECONNRESET y la prueba nunca terminó. Cerrar una sesión cancela solo
/// SUS pruebas; el motor sigue sirviendo a las demás.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalDatabase.markUnavailable();
  KeelStore.instance = const FlutterLocalDbStore();
  // The oracle is a real HTTP request reaching the engine's control API;
  // the test binding's default client answers 400 to everything.
  HttpOverrides.global = null;

  test('cerrar una sesión E2E cancela solo sus pruebas y no apaga el motor '
      'que usa otra sesión', () async {
    final cancels = <String>[];
    final api = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => api.close(force: true));
    unawaited(
      api.forEach((request) async {
        final segments = request.uri.pathSegments;
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/v1/runs') {
          final session = request.uri.queryParameters['session_id'];
          request.response.write(
            jsonEncode([
              if (session == 's_vieja')
                {
                  'run_id': 'r_3',
                  'scope': {
                    'project_id': 'p',
                    'session_id': 's_vieja',
                    'node_id': 'e2e-run',
                  },
                  'status': 'running',
                  'started_at_ms': 1,
                },
            ]),
          );
        } else if (request.method == 'POST' &&
            segments.length == 4 &&
            segments[3] == 'cancel') {
          cancels.add(segments[2]);
          request.response.write('{"status":"cancelled"}');
        } else if (request.uri.path == '/v1/stream') {
          request.response.bufferOutput = false;
          request.response.write(': open\n\n');
          return;
        } else {
          request.response.write('[]');
        }
        await request.response.close();
      }),
    );

    final tmp = Directory.systemTemp.createTempSync('keel-close-session-');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final engine = File('${tmp.path}/engine.sh')
      ..writeAsStringSync(
        '#!/bin/sh\n'
        'read -r handshake\n'
        "echo 'KEEL_E2E_READY {\"port\": ${api.port}, \"pid\": '\"\$\$\"'"
        ", \"version\": \"test\", \"schema\": 1}'\n"
        'while read -r _line; do :; done\n',
      );
    Process.runSync('chmod', ['+x', engine.path]);

    await seedE2eDeviceWorkflow();
    final workflowId = WorkflowsService.instance.notifier.data.workflows
        .firstWhere((workflow) => workflow.name == kE2eDeviceWorkflowName)
        .id;
    KeelHost.instance = const KeelHostImpl();
    final projects = ProjectsService.instance.notifier;
    await projects.ready;
    projects.updateState(
      ProjectsState(
        projects: [
          Project(
            id: 'p',
            name: 'aulamas',
            purpose: '',
            workingDirectory: tmp.path,
            createdAt: _epoch,
            activeSessionId: 's_viva',
            sessions: [
              for (final id in ['s_vieja', 's_viva'])
                Session(
                  id: id,
                  title: id,
                  createdAt: _epoch,
                  workflowId: workflowId,
                ),
            ],
          ),
        ],
        selectedProjectId: 'p',
      ),
    );

    final host = KeelE2eHostService.instance.notifier;
    addTearDown(host.detach);
    final attached = await host.attach(
      KeelE2eHostConfig(
        engineBinary: engine.path,
        dataDir: '${tmp.path}/data',
        projectRoot: tmp.path,
        sessionId: 's_viva',
      ),
    );
    final pid = attached.data.pid;

    projects.closeSession('p', 's_vieja');
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (cancels.isEmpty && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    expect(cancels, ['r_3']);
    expect(host.data, isA<HostReady>());
    expect(
      Process.runSync('kill', ['-0', '$pid']).exitCode,
      0,
      reason: 'el motor sigue vivo para la otra sesión',
    );
  });
}
