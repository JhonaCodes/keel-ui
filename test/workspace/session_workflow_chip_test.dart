import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/ui/view/session_chat_view.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';

final _epoch = DateTime(2026, 8, 23);

void main() {
  LocalDatabase.markUnavailable();

  late String tickets;

  setUp(() async {
    final workflows = WorkflowsService.instance.notifier;
    await workflows.ready;
    for (final workflow in [...workflows.data.workflows]) {
      workflows.deleteWorkflow(workflow.id);
    }
    workflows.createWorkflow(
      name: 'tickets',
      whenToApply: 'Para resolver un ticket.',
      steps: const [
        WorkflowStep(
          id: '1',
          title: 'Implementar',
          role: 'dev',
          instruction: '',
        ),
      ],
    );
    tickets = workflows.data.workflows.single.id;
  });

  Future<Project> abrir(
    WidgetTester tester, {
    List<ChatMessage> messages = const [],
    double width = 560,
  }) async {
    final project = Project(
      id: 'p',
      name: 'keel-ui',
      purpose: '',
      workingDirectory: '/tmp',
      createdAt: _epoch,
      workflowIds: [tickets],
      activeWorkflowId: tickets,
      activeSessionId: 's',
      sessions: [
        Session(
          id: 's',
          title: 'una sesión',
          createdAt: _epoch,
          workflowId: tickets,
          messages: messages,
        ),
      ],
    );
    ProjectsService.instance.notifier.updateState(
      ProjectsState(projects: [project], selectedProjectId: 'p'),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              height: 700,
              child: SessionChatView(project: project),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return project;
  }

  testWidgets('el encabezado dice con qué workflow corre la sesión', (
    tester,
  ) async {
    await abrir(tester);

    expect(find.text('tickets'), findsWidgets);
    // El encabezado es una fila apretada —título, PR, agentes, pestañas,
    // caras— y una ficha más no puede desbordarla en un panel angosto.
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin nada escrito, la ficha se puede tocar', (tester) async {
    await abrir(tester);

    await tester.tap(find.text('tickets').first);
    await tester.pumpAndSettle();

    expect(find.text('Con qué workflow corre'), findsOneWidget);
    expect(find.textContaining('Para resolver un ticket.'), findsOneWidget);
  });

  testWidgets('con el hilo empezado, no', (tester) async {
    await abrir(
      tester,
      messages: [
        ChatMessage(role: ChatRole.user, text: 'dale', timestamp: _epoch),
      ],
    );

    await tester.tap(find.text('tickets').first);
    await tester.pumpAndSettle();

    // Cambiarlo a mitad de camino dejaría medio hilo hecho por otra fila de
    // agentes: la ficha queda como cartel.
    expect(find.text('Con qué workflow corre'), findsNothing);
  });
}
