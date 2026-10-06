import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Cómo se ve la cabecera del canal con la tercera pestaña E2E (mockup
/// `06-cabecera-condicional`): `[Chat | Mapa | E2E]` cuando la sesión corre
/// un workflow que declara keel-e2e.
final _productFont = File('/System/Library/Fonts/Supplemental/Arial.ttf');
final _pubCache =
    Platform.environment['PUB_CACHE'] ??
    '${Platform.environment['HOME']}/.pub-cache';
final _materialIconsFont = File(
  '$_pubCache/hosted/pub.dev/provider-6.1.2/'
  'extension/devtools/build/assets/fonts/MaterialIcons-Regular.otf',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalDatabase.markUnavailable();
  KeelStore.instance = const FlutterLocalDbStore();

  setUpAll(() async {
    if (!await _productFont.exists() || !await _materialIconsFont.exists()) {
      return;
    }
    final bytes = ByteData.sublistView(await _productFont.readAsBytes());
    for (final family in ['GoldenArial', 'monospace']) {
      await (FontLoader(family)..addFont(Future.value(bytes))).load();
    }
    final iconBytes = ByteData.sublistView(
      await _materialIconsFont.readAsBytes(),
    );
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(iconBytes))).load();
  });

  testWidgets('cabecera con la pestaña E2E', (tester) async {
    if (!_productFont.existsSync() || !_materialIconsFont.existsSync()) {
      return;
    }

    final now = DateTime(2026, 10, 1);
    final tester1 = AgentProfile(
      id: 'qa-e2e',
      name: 'qa-e2e',
      role: 'verifier',
      systemPrompt: '',
      model: 'sonnet',
      effort: 'high',
      createdAt: now,
    );
    await AgentProfilesService.instance.notifier.ready;
    AgentProfilesService.instance.notifier.updateState(
      AgentProfilesState(profiles: [tester1]),
    );

    final workflow = Workflow(
      id: 'wf-e2e',
      name: 'E2E → diagnóstico → arreglo',
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
    await WorkflowsService.instance.notifier.ready;
    WorkflowsService.instance.notifier.updateState(
      WorkflowsState(workflows: [workflow]),
    );

    final project = Project(
      id: 'con-app',
      name: 'con-app',
      purpose: '',
      workingDirectory: '/tmp/con-app',
      profileIds: [tester1.id],
      activeSessionId: 's',
      sessions: [
        Session(
          id: 's',
          title: 'e2e: borrador de pedido',
          createdAt: now,
          workflowId: workflow.id,
        ),
      ],
      createdAt: now,
    );
    await ProjectsService.instance.notifier.ready;
    ProjectsService.instance.notifier.updateState(
      ProjectsState(projects: [project], selectedProjectId: project.id),
    );

    tester.view.physicalSize = const Size(1238, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final theme = buildAppTheme();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'GoldenArial'),
        ),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SessionChatView(project: project)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/session_header_e2e.png'),
    );
  });
}
