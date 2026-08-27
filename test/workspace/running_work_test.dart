import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/agents/model/agent.dart';
import 'package:keel_ui/src/modules/agents/model/agent_icon_colors.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/workspace/model/running_work.dart';

final _epoch = DateTime.utc(2026, 8, 27);

Session _session(String id, {bool running = false}) => Session(
  id: id,
  title: 'Sesión $id',
  createdAt: _epoch,
  request: '',
  workflowId: 'w1',
  isRunning: running,
);

Project _project(String id, {List<Session> sessions = const []}) => Project(
  id: id,
  name: id,
  purpose: '',
  workingDirectory: '/tmp/$id',
  createdAt: _epoch,
  sessions: sessions,
);

Agent _agent(String id, {bool streaming = false}) => Agent(
  id: id,
  name: id,
  model: 'sonnet',
  createdAt: _epoch,
  iconColor: kAgentIconColorPalette.first,
  effort: 'medium',
  isStreaming: streaming,
);

void main() {
  group('qué está trabajando', () {
    test('un proyecto sin sesiones no trabaja', () {
      expect(isProjectRunning(_project('a')), isFalse);
      expect(runningSessionsOf(_project('a')), 0);
    });

    test('una sesión abierta pero quieta tampoco', () {
      // `SessionStatus.running` significa ABIERTA, no ejecutando. Confundir
      // las dos es lo que hacía que la fila dijera «corriendo» siempre.
      final project = _project('a', sessions: [_session('s1')]);

      expect(isProjectRunning(project), isFalse);
    });

    test('cuenta turnos y no proyectos', () {
      // Un proyecto con dos sesiones trabajando son dos cosas pasando;
      // decir «1» ahí escondería la mitad.
      final project = _project(
        'a',
        sessions: [
          _session('s1', running: true),
          _session('s2', running: true),
          _session('s3'),
        ],
      );

      expect(runningSessionsOf(project), 2);
      expect(isProjectRunning(project), isTrue);
    });
  });

  group('los ids que hay que marcar', () {
    test('solo los proyectos con algo corriendo', () {
      final projects = [
        _project('quieto', sessions: [_session('s1')]),
        _project('activo', sessions: [_session('s2', running: true)]),
      ];

      expect(runningProjectIds(projects), {'activo'});
    });

    test('solo los agentes que están contestando', () {
      expect(runningAgentIds([_agent('a'), _agent('b', streaming: true)]), {
        'b',
      });
    });

    test('sin nada corriendo el conjunto queda vacío, no nulo', () {
      expect(runningProjectIds(const []), isEmpty);
      expect(runningAgentIds(const []), isEmpty);
    });
  });

  group('el total global', () {
    test('suma sesiones, agentes y hilos', () {
      final total = totalRunningWork(
        projects: [
          _project(
            'a',
            sessions: [_session('s1', running: true), _session('s2')],
          ),
          _project('b', sessions: [_session('s3', running: true)]),
        ],
        agents: [_agent('x', streaming: true), _agent('y')],
        thinkingRequirements: 1,
      );

      expect(total, 4);
    });

    test('sin nada, cero', () {
      expect(totalRunningWork(projects: const [], agents: const []), 0);
    });
  });
}
