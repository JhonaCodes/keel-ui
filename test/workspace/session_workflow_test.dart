import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/roadmap_format_skill.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';

ProjectsViewModel get _projects => ProjectsService.instance.notifier;
WorkflowsViewModel get _workflows => WorkflowsService.instance.notifier;

final _epoch = DateTime(2026, 8, 23);

Project _project({
  String? activeWorkflowId,
  List<Session> sessions = const [],
}) => Project(
  id: 'p',
  name: 'p',
  purpose: '',
  workingDirectory: '/tmp',
  createdAt: _epoch,
  activeWorkflowId: activeWorkflowId,
  sessions: sessions,
);

Session _session({
  String workflowId = '',
  List<ChatMessage> messages = const [],
}) => Session(
  id: 's',
  title: 's',
  createdAt: _epoch,
  workflowId: workflowId,
  messages: messages,
);

void main() {
  LocalDatabase.markUnavailable();

  String tickets = '';
  String revisiones = '';

  setUp(() async {
    await seedRoadmapFormatWorkflow();
    await _workflows.ready;
    for (final workflow in [..._workflows.data.workflows]) {
      if (workflow.name == kRoadmapFormatWorkflowName) continue;
      _workflows.deleteWorkflow(workflow.id);
    }
    _workflows.createWorkflow(
      name: 'tickets',
      whenToApply: 'Para resolver un ticket.',
      steps: const [
        WorkflowStep(
          id: '1',
          title: 'Implementar',
          role: 'dev',
          instruction: '',
        ),
        WorkflowStep(
          id: '2',
          title: 'Auditar',
          role: 'auditor',
          instruction: '',
        ),
        WorkflowStep(id: '3', title: 'Entregar', role: 'dev', instruction: ''),
      ],
    );
    _workflows.createWorkflow(
      name: 'revisiones',
      whenToApply: 'Para mirar código de otro sin tocarlo.',
      steps: const [
        WorkflowStep(
          id: '1',
          title: 'Revisar',
          role: 'auditor',
          instruction: '',
        ),
      ],
    );
    tickets = _workflows.data.workflows
        .firstWhere((workflow) => workflow.name == 'tickets')
        .id;
    revisiones = _workflows.data.workflows
        .firstWhere((workflow) => workflow.name == 'revisiones')
        .id;

    await _projects.ready;
    for (final project in [..._projects.data.projects]) {
      _projects.deleteProject(project.id);
    }
  });

  group('cada sesión corre con el suyo', () {
    test('una sesión nueva arranca con el del proyecto', () {
      _projects.createProject(
        name: 'x',
        purpose: '',
        workingDirectory: '/tmp',
        profileIds: const [],
        workflowIds: [tickets, revisiones],
        ruleNames: const [],
        knowledgeBaseNames: const [],
      );
      final id = _projects.data.projects.single.id;
      _projects.createSession(id);

      final session = _projects.data.projects.single.sessions.last;
      expect(_projects.workflowOf(session)?.name, 'tickets');
    });

    test('se puede abrir con otro, sin tocar el del proyecto', () {
      _projects.createProject(
        name: 'x',
        purpose: '',
        workingDirectory: '/tmp',
        profileIds: const [],
        workflowIds: [tickets, revisiones],
        ruleNames: const [],
        knowledgeBaseNames: const [],
      );
      final id = _projects.data.projects.single.id;
      _projects.createSession(id, workflowId: revisiones);

      final project = _projects.data.projects.single;
      expect(_projects.workflowOf(project.sessions.last)?.name, 'revisiones');
      // El del proyecto sigue siendo el de siempre: elegir para UNA sesión
      // no le cambia el default a las que vengan.
      expect(_projects.defaultWorkflowOf(project)?.name, 'tickets');
    });

    test('el 3/7 cuenta los pasos de SU workflow', () {
      expect(_projects.stepCountOf(_session(workflowId: tickets)), 3);
      expect(_projects.stepCountOf(_session(workflowId: revisiones)), 1);
      expect(_projects.stepCountOf(_session()), 0);
    });
  });

  group('cambiar el workflow de una sesión', () {
    late String id;

    setUp(() {
      _projects.createProject(
        name: 'x',
        purpose: '',
        workingDirectory: '/tmp',
        profileIds: const [],
        workflowIds: [tickets, revisiones],
        ruleNames: const [],
        knowledgeBaseNames: const [],
      );
      id = _projects.data.projects.single.id;
      _projects.createSession(id);
    });

    test('antes de arrancar, sí', () {
      final sessionId = _projects.data.projects.single.sessions.last.id;
      expect(_projects.setSessionWorkflow(id, sessionId, revisiones), isTrue);
      expect(
        _projects
            .workflowOf(_projects.data.projects.single.sessions.last)
            ?.name,
        'revisiones',
      );
    });

    test('con el hilo empezado, no', () {
      final sessionId = _projects.data.projects.single.sessions.last.id;
      _projects.sendToChannel(id, 'arrancá');

      // Media sesión hecha por una fila de agentes y la otra media por otra
      // no es una sesión: son dos pegadas.
      expect(_projects.setSessionWorkflow(id, sessionId, revisiones), isFalse);
    });
  });

  group('qué se puede elegir', () {
    test('los del proyecto, más el de formato aunque no esté enganchado', () {
      final project = _project();
      final names = [
        for (final workflow in _projects.choosableWorkflowsOf(project))
          workflow.name,
      ];
      // Es de la app y no del proyecto: obligar a engancharlo sería obligar a
      // configurar lo único que un proyecto recién creado necesita sí o sí.
      expect(names, [kRoadmapFormatWorkflowName]);
    });
  });

  group('lo guardado antes de que esto existiera', () {
    test('la marca vieja de formato se cambia por su workflow', () {
      final revivida = ProjectsViewModel.revivedSession(
        _session(workflowId: kSessionFormatMigrationMark),
        _project(activeWorkflowId: tickets),
        'wf-formato',
      );
      expect(revivida.workflowId, 'wf-formato');
    });

    test('una sesión común se queda con el del proyecto', () {
      final revivida = ProjectsViewModel.revivedSession(
        _session(),
        _project(activeWorkflowId: tickets),
        'wf-formato',
      );
      expect(revivida.workflowId, tickets);
    });

    test('una que ya lo tiene no se toca', () {
      final revivida = ProjectsViewModel.revivedSession(
        _session(workflowId: revisiones),
        _project(activeWorkflowId: tickets),
        'wf-formato',
      );
      expect(revivida.workflowId, revisiones);
    });

    test('leer el booleano viejo deja la marca', () {
      final vieja = Session.fromJson({
        'id': 's',
        'title': 'Definir el formato',
        'createdAt': _epoch.toIso8601String(),
        'isFormatSession': true,
      });
      expect(vieja.workflowId, kSessionFormatMigrationMark);
    });
  });
}
