import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_core/core/store/keel_store.dart';
import 'package:keel_ui/src/core/services/flutter_local_db_store.dart';
import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_core/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_core/modules/projects/model/project.dart';
import 'package:keel_core/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/ui/view/session_chat_view.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_core/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalDatabase.markUnavailable();
  KeelStore.instance = const FlutterLocalDbStore();

  final now = DateTime(2026, 10, 1);
  late Directory projectRoot;

  Future<void> pumpChat(WidgetTester tester, Project project) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        // The header reads AppLocalizations for the segment labels.
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(),
        home: Scaffold(body: SessionChatView(project: project)),
      ),
    );
    await tester.pump();
  }

  setUp(() async {
    projectRoot = await Directory.systemTemp.createTemp('keel-e2e-tab-');
    // Awaited here, outside any testWidgets body: a `ready` future first
    // created inside one test's FakeAsync zone never completes when the
    // next test awaits it (its listener is queued on the finished zone).
    await WorkflowsService.instance.notifier.ready;
    await ProjectsService.instance.notifier.ready;
    await AgentProfilesService.instance.notifier.ready;
    AgentProfilesService.instance.notifier.updateState(
      const AgentProfilesState(),
    );
  });

  tearDown(() async {
    await projectRoot.delete(recursive: true);
  });

  testWidgets(
    'una sesión con workflow keel-e2e muestra el segmento E2E',
    (tester) async {
      final workflow = Workflow(
        id: 'wf-e2e',
        name: 'con-e2e',
        whenToApply: '',
        createdAt: now,
        capabilities: const [
          WorkflowCapability(
            id: 'e2e-run',
            title: 'Correr E2E',
            instruction: 'Correr escenarios.',
            role: 'verifier',
            mcpServers: [kKeelE2eMcpServerName],
            outputContract: 'e2e-report',
          ),
        ],
      );
      WorkflowsService.instance.notifier.updateState(
        WorkflowsState(workflows: [workflow]),
      );

      final project = Project(
        id: 'p-e2e',
        name: 'p-e2e',
        purpose: '',
        workingDirectory: projectRoot.path,
        activeSessionId: 's',
        sessions: [
          Session(
            id: 's',
            title: 'Sesión',
            createdAt: now,
            workflowId: workflow.id,
          ),
        ],
        createdAt: now,
      );
      ProjectsService.instance.notifier.updateState(
        ProjectsState(projects: [project], selectedProjectId: project.id),
      );

      await pumpChat(tester, project);

      // RED antes del fix: el segmento `SessionTab.e2e` no existía, así que
      // la pestaña "E2E" nunca aparecía sin importar el workflow.
      expect(find.text('E2E'), findsOneWidget);
    },
  );

  testWidgets(
    // Decisión del usuario (2026-10-02): la pestaña E2E está siempre; sin
    // una prueba en curso su escenario espera, nunca muestra el dispositivo.
    'una sesión sin workflow keel-e2e también muestra el segmento E2E',
    (tester) async {
      final workflow = Workflow(
        id: 'wf-plain',
        name: 'sin-e2e',
        whenToApply: '',
        createdAt: now,
        capabilities: const [
          WorkflowCapability(
            id: 'implement',
            title: 'Implementar',
            instruction: 'Implementar.',
            role: 'implementador',
          ),
        ],
      );
      WorkflowsService.instance.notifier.updateState(
        WorkflowsState(workflows: [workflow]),
      );

      final project = Project(
        id: 'p-plain',
        name: 'p-plain',
        purpose: '',
        workingDirectory: projectRoot.path,
        activeSessionId: 's',
        sessions: [
          Session(
            id: 's',
            title: 'Sesión',
            createdAt: now,
            workflowId: workflow.id,
          ),
        ],
        createdAt: now,
      );
      ProjectsService.instance.notifier.updateState(
        ProjectsState(projects: [project], selectedProjectId: project.id),
      );

      await pumpChat(tester, project);

      expect(find.text('E2E'), findsOneWidget);
    },
  );
}
