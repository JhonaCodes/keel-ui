import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/session_queued_message.dart';
import 'package:keel_ui/src/modules/projects/ui/view/session_chat_view.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/service/workflow_deletion_service.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';

final _epoch = DateTime(2026, 8, 25);

void main() {
  LocalDatabase.markUnavailable();

  late String workflowId;

  setUp(() async {
    final workflows = WorkflowsService.instance.notifier;
    await workflows.ready;
    for (final workflow in [...workflows.data.workflows]) {
      workflowDeletionService.deleteWorkflow(workflow.id);
    }
    workflows.createWorkflow(
      name: 'resolver',
      whenToApply: 'Trabajo general.',
      kind: WorkflowKind.general,
      policy: const WorkflowPolicy(resolutionRole: 'resolver'),
    );
    workflowId = workflows.data.workflows.single.id;
  });

  Project runningProject({
    List<SessionQueuedMessage> queuedMessages = const [],
  }) {
    final project = Project(
      id: 'project',
      name: 'keel-ui',
      purpose: '',
      workingDirectory: '/tmp',
      createdAt: _epoch,
      workflowIds: [workflowId],
      activeWorkflowId: workflowId,
      activeSessionId: 'session',
      sessions: [
        Session(
          id: 'session',
          title: 'Sesión activa',
          createdAt: _epoch,
          workflowId: workflowId,
          isRunning: true,
          queuedMessages: queuedMessages,
          messages: [
            ChatMessage(
              role: ChatRole.assistant,
              text: 'Estoy trabajando.',
              timestamp: _epoch,
            ),
          ],
        ),
      ],
    );
    return project;
  }

  Future<void> openProject(WidgetTester tester, Project project) async {
    ProjectsService.instance.notifier.updateState(
      ProjectsState(projects: [project], selectedProjectId: project.id),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: SessionChatView(project: project)),
      ),
    );
    await tester.pump();
  }

  test(
    'la cola se serializa con identidad, adjuntos y decisión de entrega',
    () {
      final message = SessionQueuedMessage(
        id: 'pending-1',
        text: 'Revisá también el contrato.',
        imagePaths: const ['/tmp/evidence.png'],
        createdAt: _epoch,
        delivery: SessionQueuedDelivery.afterCurrentTurn,
      );
      final session = Session(
        id: 'session',
        title: 'Sesión',
        createdAt: _epoch,
        queuedMessages: [message],
      );

      expect(Session.fromJson(session.toJson()), session);
    },
  );

  test('edita y programa por id estable sin alterar otro mensaje', () async {
    final viewmodel = ProjectsViewModel();
    await viewmodel.ready;
    final project = runningProject();
    viewmodel.updateState(
      ProjectsState(projects: [project], selectedProjectId: project.id),
    );

    final firstId = await viewmodel.queueSessionMessage(
      project.id,
      'session',
      'primero',
    );
    final secondId = await viewmodel.queueSessionMessage(
      project.id,
      'session',
      'segundo',
    );
    await viewmodel.editQueuedSessionMessage(
      project.id,
      'session',
      firstId!,
      'primero editado',
    );
    await viewmodel.sendQueuedSessionMessageAfterTurn(
      project.id,
      'session',
      secondId!,
    );

    final queued = viewmodel.data.projects.single.activeSession!.queuedMessages;
    expect(queued.map((message) => message.id), [firstId, secondId]);
    expect(queued.first.text, 'primero editado');
    expect(queued.first.delivery, SessionQueuedDelivery.standby);
    expect(queued.last.text, 'segundo');
    expect(queued.last.delivery, SessionQueuedDelivery.afterCurrentTurn);
  });

  testWidgets('se puede escribir y guardar en espera durante un turno', (
    tester,
  ) async {
    await openProject(tester, runningProject());

    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.enabled, isTrue);
    expect(find.byTooltip('Guardar en espera'), findsOneWidget);
    expect(find.byTooltip('Detener'), findsOneWidget);
  });

  testWidgets('guarda, edita y elimina el mensaje escrito durante el turno', (
    tester,
  ) async {
    await openProject(tester, runningProject());

    await tester.enterText(find.byType(TextField).last, 'Corregí el contrato');
    await tester.tap(find.byTooltip('Guardar en espera'));
    await tester.pump();

    var project = ProjectsService.instance.notifier.data.projects.single;
    expect(
      project.activeSession!.queuedMessages.single.text,
      'Corregí el contrato',
    );

    await openProject(tester, project);
    expect(find.text('Corregí el contrato'), findsOneWidget);
    expect(find.byTooltip('Enviar ahora'), findsOneWidget);
    expect(find.byTooltip('Enviar al terminar'), findsOneWidget);

    await tester.tap(find.byTooltip('Editar mensaje en espera'));
    await tester.pump();
    await tester.enterText(
      find.byType(TextField).last,
      'Corregí el contrato y los tests',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pump();

    project = ProjectsService.instance.notifier.data.projects.single;
    expect(
      project.activeSession!.queuedMessages.single.text,
      'Corregí el contrato y los tests',
    );

    await openProject(tester, project);
    await tester.tap(find.byTooltip('Eliminar mensaje en espera'));
    await tester.pump();
    expect(
      ProjectsService
          .instance
          .notifier
          .data
          .projects
          .single
          .activeSession!
          .queuedMessages,
      isEmpty,
    );
  });
}
