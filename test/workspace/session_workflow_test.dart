import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/roadmap_format_skill.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/service/workflow_deletion_service.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalDatabase.markUnavailable();

  String tickets = '';
  String revisiones = '';

  setUp(() async {
    await seedRoadmapFormatWorkflow();
    await _workflows.ready;
    for (final workflow in [..._workflows.data.workflows]) {
      if (workflow.name == kRoadmapFormatWorkflowName) continue;
      workflowDeletionService.deleteWorkflow(workflow.id);
    }
    _workflows.createWorkflow(
      name: 'tickets',
      whenToApply: 'Para resolver un ticket.',
      kind: WorkflowKind.bug,
      policy: const WorkflowPolicy(resolutionRole: 'dev'),
    );
    _workflows.createWorkflow(
      name: 'revisiones',
      whenToApply: 'Para mirar código de otro sin tocarlo.',
      kind: WorkflowKind.general,
      policy: const WorkflowPolicy(resolutionRole: 'auditor'),
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

    test('la sesión no expone una cadena fija de pasos', () {
      expect(_projects.nodeCountOf(_session(workflowId: tickets)), 0);
      expect(_projects.nodeCountOf(_session(workflowId: revisiones)), 0);
      expect(_projects.nodeCountOf(_session()), 0);
    });
  });

  test('el canal persiste las imágenes adjuntas aunque el preflight bloquee', () async {
    _projects.createProject(
      name: 'con-imagen',
      purpose: '',
      workingDirectory: '/tmp',
      profileIds: const [],
      workflowIds: [tickets],
      ruleNames: const [],
      knowledgeBaseNames: const [],
    );
    final projectId = _projects.data.projects.single.id;
    _projects.createSession(projectId);

    await _projects.sendToChannel(
      projectId,
      '',
      imagePaths: const ['/tmp/captura.png'],
    );

    final message = _projects.data.projects.single.activeSession!.messages
        .firstWhere((entry) => entry.role == ChatRole.user);
    expect(message.imagePaths, ['/tmp/captura.png']);
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
