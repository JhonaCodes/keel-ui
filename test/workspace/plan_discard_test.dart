import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/projects/model/session_plan_item.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';

ProjectsViewModel get _projects => ProjectsService.instance.notifier;

SessionPlanItem _item(
  String text, {
  bool done = false,
  bool discarded = false,
}) => SessionPlanItem(
  id: text,
  text: text,
  done: done,
  discarded: discarded,
);

void main() {
  group('un punto descartado no es un punto cumplido', () {
    test('sale de lo pendiente sin contarse como hecho', () {
      final plan = [
        _item('uno', done: true),
        _item('dos', discarded: true),
        _item('tres'),
      ];

      expect(plan.doneCount, 1);
      expect(plan.discardedCount, 1);
      expect(plan.pending.map((item) => item.text), ['tres']);
      expect(plan.current?.text, 'tres');
    });

    test('con todo hecho o descartado, el plan cierra', () {
      final plan = [_item('uno', done: true), _item('dos', discarded: true)];
      expect(plan.isComplete, isTrue);
      expect(plan.current, isNull);
    });

    test('sobrevive al disco', () {
      final item = _item('dos', discarded: true);
      final vuelta = SessionPlanItem.fromJson(item.toJson());
      expect(vuelta.discarded, isTrue);
      expect(vuelta.pending, isFalse);
      expect(vuelta, item);
    });

    test('un plan viejo, sin la clave, no trae nada descartado', () {
      final vuelta = SessionPlanItem.fromJson({
        'id': 'x',
        'text': 'algo',
        'done': false,
      });
      expect(vuelta.discarded, isFalse);
      expect(vuelta.pending, isTrue);
    });
  });

  group('descartar desde la barra', () {
    late String projectId;
    late String sessionId;

    setUpAll(LocalDatabase.markUnavailable);

    setUp(() async {
      await _projects.ready;
      for (final project in [..._projects.data.projects]) {
        _projects.deleteProject(project.id);
      }
      _projects.createProject(
        name: 'plan',
        purpose: '',
        workingDirectory: '/tmp/keel-plan',
        profileIds: const [],
        workflowIds: const [],
        ruleNames: const [],
        knowledgeBaseNames: const [],
      );
      projectId = _projects.data.projects.single.id;
      _projects.createSession(projectId);
      sessionId = _projects.data.projects.single.sessions.last.id;
      _projects.setSessionPlan(projectId, sessionId, const [
        (text: 'Primero', ownerRole: 'implementador'),
        (text: 'Segundo', ownerRole: null),
      ]);
    });

    List<SessionPlanItem> plan() => _projects.planOf(projectId, sessionId);

    test('el punto sale de la mesa y sigue el que viene', () {
      expect(plan().current?.text, 'Primero');

      _projects.discardPlanItem(projectId, sessionId, plan().first.id);

      expect(plan().first.discarded, isTrue);
      expect(plan().first.done, isFalse);
      expect(plan().current?.text, 'Segundo');
    });

    test('queda dicho en el hilo: es una decisión, no un ajuste', () {
      _projects.discardPlanItem(projectId, sessionId, plan().first.id);

      final ultimo = _projects.data.projects.single.sessions
          .firstWhere((session) => session.id == sessionId)
          .messages
          .last;
      expect(ultimo.role, ChatRole.system);
      expect(ultimo.text, contains('descartó el punto "Primero"'));
      expect(ultimo.text, contains('No cuenta como cumplido'));
    });

    test('tocarlo de nuevo lo devuelve a la mesa, no lo marca hecho', () {
      final id = plan().first.id;
      _projects.discardPlanItem(projectId, sessionId, id);
      _projects.togglePlanItem(projectId, sessionId, id);

      expect(plan().first.discarded, isFalse);
      expect(plan().first.done, isFalse, reason: 'volver no es cumplir');
      expect(plan().current?.text, 'Primero');
    });

    test('el agente no puede resucitarlo marcándolo cumplido', () {
      final id = plan().first.id;
      _projects.discardPlanItem(projectId, sessionId, id);

      final faltantes = _projects.completePlanItems(
        projectId,
        sessionId,
        items: ['Primero'],
        byProfileId: 'alguien',
      );

      // No es un error del agente —el punto existe— pero la decisión del
      // usuario manda.
      expect(faltantes, isEmpty);
      expect(plan().first.discarded, isTrue);
      expect(plan().first.done, isFalse);
    });

    test('descartar dos veces no duplica el aviso', () {
      final id = plan().first.id;
      _projects.discardPlanItem(projectId, sessionId, id);
      final antes = _projects.data.projects.single.sessions
          .firstWhere((session) => session.id == sessionId)
          .messages
          .length;
      _projects.discardPlanItem(projectId, sessionId, id);
      final despues = _projects.data.projects.single.sessions
          .firstWhere((session) => session.id == sessionId)
          .messages
          .length;

      expect(despues, antes);
    });
  });
}
