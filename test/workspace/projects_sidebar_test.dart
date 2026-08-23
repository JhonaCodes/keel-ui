import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/core/ui/sidebar_section_row.dart';
import 'package:keel_ui/src/modules/boards/model/board.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/boards/viewmodel/boards_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/ui/view/projects_sidebar.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/workspace/model/workspace_lens.dart';
import 'package:keel_ui/src/modules/workspace/viewmodel/workspace_viewmodel.dart';

final _epoch = DateTime(2026, 8, 23);

String _project(String name) {
  final projects = ProjectsService.instance.notifier;
  projects.createProject(
    name: name,
    purpose: '',
    workingDirectory: '/tmp/keel-test-$name',
    profileIds: const [],
    workflowIds: const [],
    ruleNames: const [],
    knowledgeBaseNames: const [],
  );
  return projects.data.projects.firstWhere((entry) => entry.name == name).id;
}

void _board(String projectId, String name) {
  BoardsService.instance.notifier.upsert(
    Board(
      id: 'board-$name',
      projectId: projectId,
      name: name,
      createdAt: _epoch,
      updatedAt: _epoch,
    ),
  );
}

/// El sidebar suscripto de verdad al navegador, como en la app.
Widget _app() => MaterialApp(
  theme: buildAppTheme(),
  locale: const Locale('es'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Row(
      children: [
        ReactiveViewModelBuilder<WorkspaceViewModel, WorkspaceState>(
          viewmodel: WorkspaceService.instance.notifier,
          build: (workspace, navigator, keep) =>
              ReactiveViewModelBuilder<ProjectsViewModel, ProjectsState>(
                viewmodel: ProjectsService.instance.notifier,
                build: (state, viewmodel, keepProjects) => ProjectsSidebar(
                  state: state,
                  workspace: workspace,
                  onNewProject: () {},
                  onManageProjects: () {},
                  onManageAgents: () {},
                ),
              ),
        ),
      ],
    ),
  ),
);

void main() {
  setUpAll(LocalDatabase.markUnavailable);

  // La carga de disco se espera ANTES de sembrar. Con la base marcada como
  // no disponible devuelve vacío, pero devuelve tarde: sin esperarla, esa
  // respuesta pisa lo sembrado a mitad del test.
  // Se vacía borrando de verdad, no con `cleanState`: el `init` de estos
  // ViewModels no repone el estado inicial cuando ya cargó una vez, así que
  // lo del test anterior seguiría ahí.
  setUp(() async {
    await ProjectsService.instance.notifier.ready;
    await BoardsService.instance.notifier.ready;
    for (final board in [...BoardsService.instance.notifier.data.boards]) {
      BoardsService.instance.notifier.deleteBoard(board.id);
    }
    for (final project in [
      ...ProjectsService.instance.notifier.data.projects,
    ]) {
      ProjectsService.instance.notifier.deleteProject(project.id);
    }
    WorkspaceService.instance.notifier.cleanState();
  });

  group('las tres secciones son hermanas', () {
    testWidgets('Estado, Tableros y Sesiones, escritas igual', (tester) async {
      final projectId = _project('portal');
      WorkspaceService.instance.notifier.openProject(projectId);

      await tester.pumpWidget(_app());
      await tester.pump();

      expect(find.byType(SidebarSectionRow), findsNWidgets(3));
      final rows = tester
          .widgetList<SidebarSectionRow>(find.byType(SidebarSectionRow))
          .map((row) => row.label)
          .toList();
      expect(rows, ['Estado', 'Tableros', 'Sesiones']);
    });

    testWidgets('sin tableros el menú no gasta cuatro líneas diciéndolo', (
      tester,
    ) async {
      final projectId = _project('portal');
      WorkspaceService.instance.notifier.openProject(projectId);

      await tester.pumpWidget(_app());
      await tester.pump();

      expect(find.textContaining('Pedíselo a un agente'), findsNothing);
      expect(find.text('Nuevo tablero'), findsOneWidget);
    });
  });

  group('navegar no choca entre secciones', () {
    testWidgets('una sesión, con un tablero abierto', (tester) async {
      final navigator = WorkspaceService.instance.notifier;
      final projectId = _project('portal');
      navigator.openNewSession(projectId);
      _board(projectId, 'Lanzar oferta');

      await tester.pumpWidget(_app());
      await tester.pump();

      await tester.tap(find.text('Lanzar oferta'));
      await tester.pump();
      expect(navigator.data.lens, WorkspaceLens.board);

      // El bug del reporte: con el tablero adelante, tocar la sesión no
      // llevaba a ninguna parte.
      //
      // El pump largo no es adorno: la fila de una sesión escucha el doble
      // click para renombrar, así que el tap simple espera a que el doble se
      // rinda. Con un `pump()` pelado el gesto todavía no salió.
      await tester.tap(find.text('Sesión nueva'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(navigator.data.lens, WorkspaceLens.session);
    });

    testWidgets('la sección Tableros lleva a su pantalla', (tester) async {
      final navigator = WorkspaceService.instance.notifier;
      final projectId = _project('portal');
      navigator.openNewSession(projectId);

      await tester.pumpWidget(_app());
      await tester.pump();

      await tester.tap(find.text('Tableros'));
      await tester.pump();
      expect(navigator.data.lens, WorkspaceLens.boards);
      expect(navigator.data.boardId, isNull);
    });

    testWidgets('y Estado también, desde un tablero', (tester) async {
      final navigator = WorkspaceService.instance.notifier;
      final projectId = _project('portal');
      _board(projectId, 'Lanzar oferta');
      navigator.openBoard('board-Lanzar oferta');

      await tester.pumpWidget(_app());
      await tester.pump();

      await tester.tap(find.text('Estado'));
      await tester.pump();
      expect(navigator.data.lens, WorkspaceLens.projectState);
    });
  });

  group('las listas se pliegan', () {
    testWidgets('el galón cierra los tableros sin navegar', (tester) async {
      final navigator = WorkspaceService.instance.notifier;
      final projectId = _project('portal');
      navigator.openProjectState(projectId);
      _board(projectId, 'Lanzar oferta');

      await tester.pumpWidget(_app());
      await tester.pump();
      expect(find.text('Lanzar oferta'), findsOneWidget);

      final tableros = find.ancestor(
        of: find.text('Tableros'),
        matching: find.byType(SidebarSectionRow),
      );
      await tester.tap(
        find.descendant(
          of: tableros,
          matching: find.byIcon(Icons.arrow_drop_down),
        ),
      );
      await tester.pump();

      expect(find.text('Lanzar oferta'), findsNothing);
      expect(navigator.data.lens, WorkspaceLens.projectState);
    });
  });

  group('borrar un tablero', () {
    testWidgets('se puede desde el menú, sin entrar al banco', (tester) async {
      final projectId = _project('portal');
      WorkspaceService.instance.notifier.openProject(projectId);
      _board(projectId, 'Lanzar oferta');

      await tester.pumpWidget(_app());
      await tester.pump();

      await tester.tap(find.byTooltip('Eliminar tablero'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('Lanzar oferta'), findsNothing);
      expect(
        BoardsService.instance.notifier.data.forProject(projectId),
        isEmpty,
      );
    });
  });
}
