import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agents/model/agent_tool_activity.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/model/permission_request.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/session_live_turn.dart';
import 'package:keel_ui/src/modules/projects/model/session_map.dart';
import 'package:keel_ui/src/modules/projects/model/session_subagent.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

final _epoch = DateTime(2026, 8, 23);

AgentProfile _member(String name, {String? role, String? createdBy}) =>
    AgentProfile(
      id: name,
      name: name,
      role: role ?? name,
      systemPrompt: '',
      model: 'sonnet',
      effort: 'normal',
      createdAt: _epoch,
      createdByProfileId: createdBy,
    );

Workflow _workflow(List<(String, String)> steps) => Workflow(
  id: 'wf',
  name: 'tdd',
  whenToApply: '',
  createdAt: _epoch,
  steps: [
    for (final (title, role) in steps)
      WorkflowStep(id: title, title: title, role: role, instruction: ''),
  ],
);

ChatMessage _said(
  String author,
  String text, {
  int? step,
  String? consultOf,
  int durationMs = 1000,
  double costUsd = 0.1,
}) => ChatMessage(
  role: ChatRole.assistant,
  text: text,
  timestamp: _epoch,
  authorProfileId: author,
  stepIndex: step,
  consultOfProfileId: consultOf,
  durationMs: durationMs,
  costUsd: costUsd,
);

Session _session({
  List<ChatMessage> messages = const [],
  List<SessionSubagent> subagents = const [],
  SessionLiveTurn? liveTurn,
  bool isRunning = false,
  int currentStepIndex = 0,
  SessionStatus status = SessionStatus.running,
  PermissionRequest? pendingPermission,
}) => Session(
  id: 's1',
  title: 'sesión',
  createdAt: _epoch,
  messages: messages,
  subagents: subagents,
  liveTurn: liveTurn,
  isRunning: isRunning,
  currentStepIndex: currentStepIndex,
  status: status,
  pendingPermission: pendingPermission,
);

SessionSubagent _sub(
  String id, {
  required String parent,
  int? step,
  SubagentPhase phase = SubagentPhase.thinking,
  String result = '',
  String ask = 'buscá el precio',
}) => SessionSubagent(
  id: id,
  parentProfileId: parent,
  parentStepIndex: step,
  agentType: 'Explore',
  ask: ask,
  prompt: 'prompt largo',
  startedAt: _epoch,
  phase: phase,
  result: result,
  finishedAt: phase == SubagentPhase.thinking ? null : _epoch,
);

void main() {
  group('el lienzo en reposo', () {
    test('con workflow, hay una columna por PASO y no por agente', () {
      // El caso real que rompe cualquier "un nodo por miembro": el mismo
      // miembro tiene tres de los cuatro pasos.
      final map = SessionMap.from(
        session: null,
        members: [_member('planificador'), _member('flutter-expert')],
        workflow: _workflow([
          ('Charter', 'planificador'),
          ('RED', 'flutter-expert'),
          ('GREEN', 'flutter-expert'),
          ('Refactor', 'flutter-expert'),
        ]),
      );

      final row = map.nodes.where((node) => node.lane == 0).toList();
      expect(row.map((node) => node.id), [
        'you',
        'step:0',
        'step:1',
        'step:2',
        'step:3',
        'end',
      ]);
      expect(row.map((node) => node.label), [
        'vos',
        'planificador',
        'flutter-expert',
        'flutter-expert',
        'flutter-expert',
        'fin',
      ]);
      expect(row.map((node) => node.column), [0, 1, 2, 3, 4, 5]);
    });

    test('sin nada corrido, todos los nodos están en reposo', () {
      final map = SessionMap.from(
        session: null,
        members: [_member('a'), _member('b')],
        workflow: _workflow([('Uno', 'a'), ('Dos', 'b')]),
      );

      expect(
        map.nodes.every((node) => node.state == MapNodeState.idle),
        isTrue,
      );
      expect(
        map.edges.every((edge) => edge.kind == MapEdgeKind.untraveled),
        isTrue,
      );
      expect(map.edges.any((edge) => edge.live), isFalse);
    });

    test('sin workflow, el elenco se acomoda igual', () {
      final map = SessionMap.from(
        session: null,
        members: [_member('a'), _member('b')],
        workflow: null,
      );

      expect(map.nodes.map((node) => node.id), [
        'you',
        'free:a',
        'free:b',
        'end',
      ]);
    });

    test('un paso cuyo rol no lo tiene nadie no inventa una columna', () {
      final map = SessionMap.from(
        session: null,
        members: [_member('a')],
        workflow: _workflow([('Uno', 'a'), ('Dos', 'nadie')]),
      );

      expect(
        map.nodes.where((node) => node.kind == MapNodeKind.step).length,
        1,
      );
    });
  });

  group('el vuelo', () {
    test('la línea se mueve mientras viaja y se apaga cuando llega', () {
      final enVuelo = SessionMap.from(
        session: _session(
          isRunning: true,
          currentStepIndex: 0,
          liveTurn: const SessionLiveTurn(profileId: 'a'),
        ),
        members: [_member('a'), _member('b')],
        workflow: _workflow([('Uno', 'a'), ('Dos', 'b')]),
      );
      final entrante = enVuelo.edges.firstWhere(
        (edge) => edge.toId == 'step:0',
      );
      expect(entrante.live, isTrue);

      final llegado = SessionMap.from(
        session: _session(
          isRunning: true,
          currentStepIndex: 0,
          messages: [_said('a', 'Listo.', step: 0)],
          liveTurn: const SessionLiveTurn(
            profileId: 'a',
            phase: TurnPhase.working,
          ),
        ),
        members: [_member('a'), _member('b')],
        workflow: _workflow([('Uno', 'a'), ('Dos', 'b')]),
      );
      expect(
        llegado.edges.firstWhere((edge) => edge.toId == 'step:0').live,
        isFalse,
      );
      // El que se mueve pasa a ser el nodo.
      expect(llegado.nodeById('step:0')!.state, MapNodeState.working);
    });

    test('las tres fases del turno son tres estados del nodo', () {
      for (final (phase, state) in [
        (TurnPhase.thinking, MapNodeState.thinking),
        (TurnPhase.working, MapNodeState.working),
        (TurnPhase.writing, MapNodeState.writing),
      ]) {
        final map = SessionMap.from(
          session: _session(
            isRunning: true,
            liveTurn: SessionLiveTurn(profileId: 'a', phase: phase),
          ),
          members: [_member('a')],
          workflow: _workflow([('Uno', 'a')]),
        );
        expect(map.nodeById('step:0')!.state, state);
        expect(map.nodeById('step:0')!.isLive, isTrue);
      }
    });

    test('un permiso pendiente traba al nodo, no a la sesión entera', () {
      final map = SessionMap.from(
        session: _session(
          isRunning: true,
          liveTurn: const SessionLiveTurn(profileId: 'a'),
          pendingPermission: const PermissionRequest(
            toolName: 'Bash',
            message: 'git push',
          ),
        ),
        members: [_member('a'), _member('b')],
        workflow: _workflow([('Uno', 'a'), ('Dos', 'b')]),
      );

      expect(map.nodeById('step:0')!.state, MapNodeState.waiting);
      expect(map.nodeById('step:1')!.state, MapNodeState.idle);
    });

    test('el nodo cerrado muestra la primera frase y sus números', () {
      final map = SessionMap.from(
        session: _session(
          messages: [
            _said(
              'a',
              'El bid entra por WebSocket. Después vemos el resto.',
              step: 0,
              durationMs: 2500,
              costUsd: 0.4,
            ),
          ],
        ),
        members: [_member('a')],
        workflow: _workflow([('Uno', 'a')]),
      );

      final node = map.nodeById('step:0')!;
      expect(node.state, MapNodeState.done);
      expect(node.resolved, 'El bid entra por WebSocket.');
      expect(node.elapsed, const Duration(milliseconds: 2500));
      expect(node.costUsd, closeTo(0.4, 0.001));
      expect(
        map.edges.firstWhere((e) => e.toId == 'step:0').kind,
        MapEdgeKind.forward,
      );
    });

    test('la sesión terminada enciende la entrega final', () {
      final map = SessionMap.from(
        session: _session(
          status: SessionStatus.finished,
          messages: [_said('a', 'Listo.', step: 0)],
        ),
        members: [_member('a')],
        workflow: _workflow([('Uno', 'a')]),
      );

      expect(
        map.edges.firstWhere((edge) => edge.toId == 'end').kind,
        MapEdgeKind.finish,
      );
      expect(map.nodeById('end')!.state, MapNodeState.done);
    });
  });

  group('la réplica hacia atrás', () {
    test('preguntar y contestar son dos líneas distintas', () {
      final map = SessionMap.from(
        session: _session(
          messages: [
            _said('a', 'Che @b, ¿el contrato lleva version?', step: 0),
            _said('b', 'No lleva.', step: 0, consultOf: 'a'),
          ],
        ),
        members: [_member('a'), _member('b')],
        workflow: _workflow([('Uno', 'a'), ('Dos', 'b')]),
      );

      final back = map.edges.firstWhere((e) => e.kind == MapEdgeKind.back);
      final answer = map.edges.firstWhere((e) => e.kind == MapEdgeKind.answer);
      expect(back.fromId, 'step:0');
      expect(back.toId, 'step:1');
      expect(answer.fromId, 'step:1');
      expect(answer.toId, 'step:0');
      expect(back.label, 'Che @b, ¿el contrato lleva version?');
    });

    test('diez consultas entre el mismo par son UNA línea y un contador', () {
      final map = SessionMap.from(
        session: _session(
          messages: [
            for (var i = 0; i < 10; i++) ...[
              _said('a', 'Che @b, la $i', step: 0),
              _said('b', 'Ahí va.', step: 0, consultOf: 'a'),
            ],
          ],
        ),
        members: [_member('a'), _member('b')],
        workflow: _workflow([('Uno', 'a'), ('Dos', 'b')]),
      );

      expect(map.edges.where((e) => e.kind == MapEdgeKind.back).length, 1);
      expect(map.edges.where((e) => e.kind == MapEdgeKind.answer).length, 1);
      expect(map.nodeById('step:1')!.backCalls, 10);
    });

    test('el que contesta cambia de estado, no suma un cuadro', () {
      final map = SessionMap.from(
        session: _session(
          isRunning: true,
          currentStepIndex: 0,
          messages: [_said('b', 'Ya terminé.', step: 1)],
          liveTurn: const SessionLiveTurn(
            profileId: 'b',
            consultOfProfileId: 'a',
          ),
        ),
        members: [_member('a'), _member('b')],
        workflow: _workflow([('Uno', 'a'), ('Dos', 'b')]),
      );

      expect(map.nodeById('step:1')!.state, MapNodeState.replying);
      expect(map.nodes.where((n) => n.profileId == 'b').length, 1);
    });

    test('la consulta en vuelo se ve antes de que haya mensaje', () {
      final map = SessionMap.from(
        session: _session(
          isRunning: true,
          messages: [_said('a', 'Che @b, ¿y esto?', step: 0)],
          liveTurn: const SessionLiveTurn(
            profileId: 'b',
            consultOfProfileId: 'a',
          ),
        ),
        members: [_member('a'), _member('b')],
        workflow: _workflow([('Uno', 'a'), ('Dos', 'b')]),
      );

      final back = map.edges.firstWhere((e) => e.kind == MapEdgeKind.back);
      expect(back.live, isTrue);
      expect(back.label, 'Che @b, ¿y esto?');
    });
  });

  group('el carril de abajo', () {
    test('un subagente cuelga del PASO que lo abrió, no del miembro', () {
      final map = SessionMap.from(
        session: _session(
          messages: [_said('a', 'uno', step: 0), _said('a', 'dos', step: 1)],
          subagents: [_sub('t1', parent: 'a', step: 1)],
        ),
        members: [_member('a')],
        workflow: _workflow([('Uno', 'a'), ('Dos', 'a')]),
      );

      final sub = map.nodeById('sub:t1')!;
      expect(sub.lane, 1);
      expect(sub.column, map.nodeById('step:1')!.column);
      expect(map.nodeById('step:0')!.subagentCount, 0);
      expect(map.nodeById('step:1')!.subagentCount, 1);
    });

    test('mientras corre, la línea va; cuando devuelve, vuelve', () {
      final corriendo = SessionMap.from(
        session: _session(subagents: [_sub('t1', parent: 'a', step: 0)]),
        members: [_member('a')],
        workflow: _workflow([('Uno', 'a')]),
      );
      final ida = corriendo.edges.firstWhere((e) => e.toId == 'sub:t1');
      expect(ida.kind, MapEdgeKind.delegate);
      expect(ida.live, isTrue);
      expect(ida.label, 'buscá el precio');

      final devuelto = SessionMap.from(
        session: _session(
          subagents: [
            _sub(
              't1',
              parent: 'a',
              step: 0,
              phase: SubagentPhase.done,
              result: 'Está en lot_repository.dart. Línea 88.',
            ),
          ],
        ),
        members: [_member('a')],
        workflow: _workflow([('Uno', 'a')]),
      );
      final vuelta = devuelto.edges.firstWhere((e) => e.toId == 'sub:t1');
      expect(vuelta.kind, MapEdgeKind.delegateBack);
      expect(vuelta.live, isFalse);
      expect(
        devuelto.nodeById('sub:t1')!.resolved,
        'Está en lot_repository.dart.',
      );
    });

    test('más de cuatro se agrupan, y el resto se cuenta', () {
      final session = _session(
        subagents: [
          for (var i = 0; i < 7; i++) _sub('t$i', parent: 'a', step: 0),
        ],
      );
      final map = SessionMap.from(
        session: session,
        members: [_member('a')],
        workflow: _workflow([('Uno', 'a')]),
      );

      expect(map.nodes.where((n) => n.lane == 1).length, kSubagentsDrawn);
      final padre = map.nodeById('step:0')!;
      expect(padre.subagentCount, 7);
      expect(padre.hiddenSubagents, 3);
    });

    test('abrir la píldora los dibuja a todos', () {
      final map = SessionMap.from(
        session: _session(
          subagents: [
            for (var i = 0; i < 7; i++) _sub('t$i', parent: 'a', step: 0),
          ],
        ),
        members: [_member('a')],
        workflow: _workflow([('Uno', 'a')]),
        expandedParents: {'step:0'},
      );

      expect(map.nodes.where((n) => n.lane == 1).length, 7);
      expect(map.nodeById('step:0')!.hiddenSubagents, 0);
    });

    test('el subagente lleva su propio estado, en paralelo al del padre', () {
      final map = SessionMap.from(
        session: _session(
          isRunning: true,
          liveTurn: const SessionLiveTurn(
            profileId: 'a',
            phase: TurnPhase.working,
            activity: AgentToolActivity(
              kind: AgentToolKind.task,
              label: 'Delegando a Explore: buscá el precio',
            ),
          ),
          subagents: [_sub('t1', parent: 'a', step: 0)],
        ),
        members: [_member('a')],
        workflow: _workflow([('Uno', 'a')]),
      );

      expect(map.nodeById('step:0')!.state, MapNodeState.working);
      expect(map.nodeById('sub:t1')!.state, MapNodeState.thinking);
    });
  });

  group('el elenco', () {
    test('quién registró a quién se ve desde que abrís el mapa', () {
      final map = SessionMap.from(
        session: null,
        members: [
          _member('a'),
          _member('b', createdBy: 'a'),
        ],
        workflow: _workflow([('Uno', 'a'), ('Dos', 'b')]),
      );

      final spawn = map.edges.firstWhere((e) => e.kind == MapEdgeKind.spawn);
      expect(spawn.fromId, 'step:0');
      expect(spawn.toId, 'step:1');
      expect(spawn.live, isFalse);
    });

    test('un creador que no es miembro no dibuja nada', () {
      final map = SessionMap.from(
        session: null,
        members: [_member('b', createdBy: 'fantasma')],
        workflow: _workflow([('Dos', 'b')]),
      );

      expect(map.edges.any((e) => e.kind == MapEdgeKind.spawn), isFalse);
    });
  });

  group('el cuadro de una réplica', () {
    SessionMap mapOf(List<ChatMessage> messages, {SessionLiveTurn? live}) =>
        SessionMap.from(
          session: _session(
            messages: messages,
            liveTurn: live,
            isRunning: live != null,
          ),
          members: [_member('arquitecto'), _member('rn-expert')],
          workflow: _workflow([
            ('Diseño', 'arquitecto'),
            ('Implementar', 'rn-expert'),
          ]),
        );

    test('cerrada, muestra la RESPUESTA y no desaparece', () {
      // La regresión que reportó el usuario: con la sesión terminada el mapa
      // dibujaba el arco y un contador, y en ninguna parte decía qué se
      // habían preguntado.
      final map = mapOf([
        _said('arquitecto', 'Va por WebSocket. @rn-expert ¿el contrato lleva version?', step: 0),
        _said('rn-expert', 'Sin version. Va en el header del canal.', consultOf: 'arquitecto'),
      ]);

      expect(map.callouts, hasLength(1));
      final callout = map.callouts.single;
      expect(callout.live, isFalse);
      expect(callout.title, 'rn-expert → arquitecto');
      expect(callout.text, 'Sin version.');
    });

    test('en vuelo, muestra el PEDIDO y gana sobre la cerrada del par', () {
      final map = mapOf(
        [
          _said('arquitecto', 'Va por WebSocket. @rn-expert ¿el contrato lleva version?', step: 0),
          _said('rn-expert', 'Sin version.', consultOf: 'arquitecto'),
          _said('arquitecto', 'Gracias. @rn-expert ¿y el precio del lote?', step: 0),
        ],
        live: const SessionLiveTurn(
          profileId: 'rn-expert',
          phase: TurnPhase.thinking,
          consultOfProfileId: 'arquitecto',
        ),
      );

      // Un cuadro por PAR, no uno por consulta: la de ahora manda.
      expect(map.callouts, hasLength(1));
      expect(map.callouts.single.live, isTrue);
      expect(map.callouts.single.title, 'arquitecto → rn-expert');
      expect(map.callouts.single.text, contains('precio del lote'));
    });

    test('diez idas y vueltas siguen siendo un solo cuadro', () {
      final map = mapOf([
        for (var i = 0; i < 10; i++) ...[
          _said('arquitecto', 'Pregunta $i para @rn-expert.', step: 0),
          _said('rn-expert', 'Respuesta $i.', consultOf: 'arquitecto'),
        ],
      ]);

      expect(map.callouts, hasLength(1));
      expect(map.callouts.single.text, 'Respuesta 9.');
    });

    test('el nodo guarda las anteriores enteras, para poder abrirlas', () {
      final map = mapOf([
        _said('arquitecto', 'Primera: @rn-expert ¿lleva version?', step: 0),
        _said('rn-expert', 'Sin version.', consultOf: 'arquitecto'),
        _said('arquitecto', 'Segunda: @rn-expert ¿y el precio?', step: 0),
        _said('rn-expert', 'Sale del lote.', consultOf: 'arquitecto'),
      ]);

      final answerer = map.nodes.firstWhere((node) => node.label == 'rn-expert');
      expect(answerer.consults, hasLength(2));
      expect(answerer.backCalls, 2);
      expect(answerer.consults.first.askedBy, 'arquitecto');
      expect(answerer.consults.first.ask, contains('lleva version'));
      expect(answerer.consults.first.answer, 'Sin version.');
      expect(answerer.consults.last.answer, 'Sale del lote.');
    });

    test('sin consultas no hay cuadros', () {
      final map = mapOf([_said('arquitecto', 'Listo.', step: 0)]);
      expect(map.callouts, isEmpty);
    });
  });
}
