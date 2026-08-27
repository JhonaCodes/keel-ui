import 'package:flutter/gestures.dart';
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
import 'package:keel_ui/src/modules/sidebar_layout/model/sidebar_layout.dart';
import 'package:keel_ui/src/modules/sidebar_layout/ui/widget/sidebar_group_row.dart';
import 'package:keel_ui/src/modules/sidebar_layout/viewmodel/sidebar_layout_viewmodel.dart';
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

/// Abre una sección del proyecto (Tableros / Sesiones), que ahora arrancan
/// plegadas: entrar a un proyecto no es pedir que se despliegue todo.
Future<void> _abrirSeccion(WidgetTester tester, String label) async {
  final fila = find.ancestor(
    of: find.text(label),
    matching: find.byType(SidebarSectionRow),
  );
  await tester.tap(
    find.descendant(of: fila, matching: find.byIcon(Icons.arrow_right)),
  );
  await tester.pumpAndSettle();
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

    // La disposición del sidebar es persistente: sin vaciarla, los grupos
    // que arma un test aparecen en el siguiente.
    final layout = SidebarLayoutService.instance.notifier;
    await layout.ready;
    for (final kind in SidebarSectionKind.values) {
      final slots = layout.slotsFor(kind, const <String>[]);
      for (final slot in slots) {
        if (slot is SidebarGroupSlot) {
          await layout.ungroup(kind, slot.id, presentIds: const []);
        }
      }
    }
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

      await _abrirSeccion(tester, 'Tableros');

      expect(find.textContaining('Pedíselo a un agente'), findsNothing);
      expect(find.text('Nuevo tablero'), findsOneWidget);
    });
  });

  group('las secciones del proyecto arrancan plegadas', () {
    testWidgets('abrir un proyecto no despliega Tableros ni Sesiones', (
      tester,
    ) async {
      // Antes el estado arrancaba en `true` y no se guardaba, así que entrar
      // a un proyecto abría las dos secciones solo.
      final projectId = _project('portal');
      WorkspaceService.instance.notifier.openNewSession(projectId);
      _board(projectId, 'Lanzar oferta');

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Lanzar oferta'), findsNothing);
      expect(find.text('Sesión nueva'), findsNothing);
    });

    testWidgets('lo que abriste queda abierto', (tester) async {
      final projectId = _project('portal');
      WorkspaceService.instance.notifier.openProject(projectId);
      _board(projectId, 'Lanzar oferta');

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _abrirSeccion(tester, 'Tableros');

      expect(
        SidebarLayoutService.instance.notifier.isSectionOpen(
          'boards:$projectId',
        ),
        isTrue,
      );
      expect(find.text('Lanzar oferta'), findsOneWidget);
    });

    testWidgets('y es de cada proyecto, no de la barra entera', (tester) async {
      // Antes los dos flags eran uno solo para todo el sidebar: abrir
      // Tableros en un proyecto los abría en todos.
      final portal = _project('portal');
      final tienda = _project('tienda');
      _board(portal, 'Lanzar oferta');
      _board(tienda, 'Otro tablero');
      WorkspaceService.instance.notifier.openProject(portal);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _abrirSeccion(tester, 'Tableros');
      expect(find.text('Lanzar oferta'), findsOneWidget);

      WorkspaceService.instance.notifier.openProject(tienda);
      await tester.pumpAndSettle();

      expect(find.text('Otro tablero'), findsNothing);
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
      await _abrirSeccion(tester, 'Tableros');
      await _abrirSeccion(tester, 'Sesiones');

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
      await _abrirSeccion(tester, 'Tableros');
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
      await _abrirSeccion(tester, 'Tableros');

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

  group('acomodar la lista', () {
    /// Arrastra la fila de un proyecto sobre la de otro, apuntando al centro
    /// —que es el gesto de agrupar— y suelta.
    Future<void> arrastrarSobre(
      WidgetTester tester, {
      required String desde,
      required String hasta,
    }) async {
      final origen = tester.getCenter(find.text(desde));
      final destino = tester.getCenter(find.text(hasta));
      final gesto = await tester.startGesture(origen);
      // Un paso corto primero: el Draggable arranca recién cuando el puntero
      // se movió, y saltar directo al destino se pierde el arranque.
      await tester.pump(const Duration(milliseconds: 20));
      await gesto.moveTo(origen + const Offset(0, 6));
      await tester.pump();
      await gesto.moveTo(destino);
      await tester.pump();
      await gesto.up();
      await tester.pumpAndSettle();
      // El soltar cuenta como un click: sin esta pausa, el tap que hace el
      // test a continuación entra como doble click y abre el renombre en
      // vez de plegar.
      await tester.pump(const Duration(milliseconds: 400));
    }

    /// La fila del grupo también renombra con doble click, así que un tap
    /// simple no cuenta hasta que vence el plazo del doble.
    Future<void> plegar(WidgetTester tester) async {
      await tester.tap(find.byType(SidebarGroupRow));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }

    testWidgets('arrastrar un proyecto sobre otro crea el grupo', (
      tester,
    ) async {
      _project('alfa');
      _project('beta');
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await arrastrarSobre(tester, desde: 'beta', hasta: 'alfa');

      expect(find.byType(SidebarGroupRow), findsOneWidget);
      final grupo = SidebarLayoutService.instance.notifier.groupOf(
        SidebarSectionKind.project,
        'alfa',
      );
      expect(grupo, isNull, reason: 'los grupos guardan ids, no nombres');
      expect(
        SidebarLayoutService.instance.notifier
            .slotsFor(SidebarSectionKind.project, [
              for (final p in ProjectsService.instance.notifier.data.projects)
                p.id,
            ])
            .whereType<SidebarGroupSlot>()
            .single
            .memberIds,
        hasLength(2),
      );
      // Los dos proyectos siguen visibles adentro del grupo.
      expect(find.text('alfa'), findsOneWidget);
      expect(find.text('beta'), findsOneWidget);
    });

    testWidgets('el galón del grupo lo pliega sin borrar nada', (tester) async {
      _project('alfa');
      _project('beta');
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await arrastrarSobre(tester, desde: 'beta', hasta: 'alfa');

      await plegar(tester);

      expect(find.text('alfa'), findsNothing);
      expect(find.byType(SidebarGroupRow), findsOneWidget);

      await plegar(tester);
      expect(find.text('alfa'), findsOneWidget);
    });

    testWidgets('plegado, lo que está abierto se sigue viendo', (tester) async {
      // Al estilo Slack: plegar es dejar de mirar el resto, no perder de
      // vista dónde estás parado. Sin esto, la fila abierta desaparecía de
      // la barra y no había forma de saber en qué grupo buscarla.
      final alfa = _project('alfa');
      _project('beta');
      WorkspaceService.instance.notifier.openProject(alfa);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await arrastrarSobre(tester, desde: 'beta', hasta: 'alfa');

      await plegar(tester);

      expect(find.text('alfa'), findsOneWidget, reason: 'es el abierto');
      expect(find.text('beta'), findsNothing);
    });

    testWidgets('el click derecho abre un menú y no borra el grupo', (
      tester,
    ) async {
      // Antes deshacía el grupo en el acto, sin preguntar y sin deshacer: la
      // fila desaparecía y los miembros quedaban sueltos.
      _project('alfa');
      _project('beta');
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await arrastrarSobre(tester, desde: 'beta', hasta: 'alfa');

      final centro = tester.getCenter(find.byType(SidebarGroupRow));
      final gesto = await tester.startGesture(
        centro,
        buttons: kSecondaryButton,
      );
      await gesto.up();
      await tester.pumpAndSettle();

      expect(find.text('Deshacer el grupo'), findsOneWidget);
      expect(find.text('Renombrar'), findsOneWidget);
      expect(find.byType(SidebarGroupRow), findsOneWidget);
    });

    testWidgets('el doble click renombra el grupo', (tester) async {
      _project('alfa');
      _project('beta');
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await arrastrarSobre(tester, desde: 'beta', hasta: 'alfa');

      await tester.tap(find.text('Grupo'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Grupo'), warnIfMissed: false);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Clientes');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Clientes'), findsOneWidget);
    });
  });
}
