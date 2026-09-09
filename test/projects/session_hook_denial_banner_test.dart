import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/model/permission_request.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/permission_request_banner.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/ui/view/session_chat_view.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/service/workflow_deletion_service.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';

final _epoch = DateTime(2026, 8, 28);

/// El stderr real de un guardarraíl: quince renglones que la tarjeta mostraba
/// enteros, una vez por disparo.
const _hookStderr =
    "PreToolUse:Edit hook error: [bash '/var/folders/x9/tmp/hooks/"
    "flutter-invariants-guard.sh']: BLOQUEADO (flutter-standards 1 / policy "
    '5.C): una funcion que devuelve un widget esta prohibida en este repo. '
    'El subarbol no tiene identidad propia, asi que Flutter no le da Element '
    'ni State, no lo saltea con const y no aparece en el arbol de widgets. '
    'Convertilo en una clase StatelessWidget o StatefulWidget. Si el widget '
    'se usa en un solo archivo, dejalo privado con prefijo guion bajo; si lo '
    'usa mas de uno, movelo al kit compartido.\n'
    '[keel:hook flutter-invariants-guard]';

const _footer =
    'No hay permiso que conceder: esto lo decidió un guardarraíl. Si sobra, '
    'apagalo en Hooks — o pedíselo a Keel AI, que corre sin hooks.';

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

  Project blockedProject() => Project(
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
        messages: [
          ChatMessage(
            role: ChatRole.assistant,
            text: 'Voy a editar el archivo.',
            timestamp: _epoch,
          ),
        ],
        pendingPermission: const PermissionRequest(
          toolName: 'Edit',
          message: _hookStderr,
        ),
      ),
    ],
  );

  Future<void> openProject(WidgetTester tester, Project project) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ProjectsService.instance.notifier.updateState(
      ProjectsState(projects: [project], selectedProjectId: project.id),
    );
    await tester.pumpWidget(
      MaterialApp(
        // The widgets under test read AppLocalizations; without the
        // delegates `AppLocalizations.of` returns null and build throws.
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(),
        home: Scaffold(body: SessionChatView(project: project)),
      ),
    );
    await tester.pump();
  }

  testWidgets('el aviso de hook entra colapsado y el detalle va al panel', (
    tester,
  ) async {
    await openProject(tester, blockedProject());

    // Colapsada: el motivo se corta y el pie no está en el hilo.
    expect(find.byType(PermissionRequestBanner), findsOneWidget);
    expect(find.text(_footer), findsNothing);
    expect(
      tester.getSize(find.byType(PermissionRequestBanner)).height,
      lessThan(100),
    );

    // Tocarla abre el panel lateral con el mensaje entero y el pie.
    await tester.tap(find.textContaining('frenó Edit'));
    await tester.pumpAndSettle();

    expect(find.byType(HookDenialDetailPanel), findsOneWidget);
    expect(find.text(_footer), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SelectableText && widget.data == _hookStderr,
      ),
      findsOneWidget,
    );
  });

  testWidgets('descartarlo lo saca del hilo y no vuelve al reconstruirlo', (
    tester,
  ) async {
    await openProject(tester, blockedProject());

    await tester.tap(find.byTooltip('Descartar'));
    await tester.pump();

    final project = ProjectsService.instance.notifier.data.projects.single;
    expect(project.activeSession!.pendingPermission, isNull);

    await openProject(tester, project);
    expect(find.byType(PermissionRequestBanner), findsNothing);
  });
}
