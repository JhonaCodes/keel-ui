import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/modules/boards/model/board.dart';
import 'package:keel_ui/src/modules/boards/ui/view/project_boards_view.dart';
import 'package:keel_ui/src/modules/boards/viewmodel/boards_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/workspace/model/workspace_lens.dart';
import 'package:keel_ui/src/modules/workspace/viewmodel/workspace_viewmodel.dart';

final _epoch = DateTime(2026, 8, 23);

final _project = Project(
  id: 'p1',
  name: 'aulamas-portal',
  purpose: '',
  workingDirectory: '/tmp/aulamas-portal',
  createdAt: _epoch,
);

void _board(String name) {
  BoardsService.instance.notifier.upsert(
    Board(
      id: 'board-$name',
      projectId: _project.id,
      name: name,
      note: 'Contra la API de desarrollo.',
      createdAt: _epoch,
      updatedAt: _epoch,
    ),
  );
}

Widget _app() => MaterialApp(
  theme: buildAppTheme(),
  home: Scaffold(
    body: SizedBox(
      width: 900,
      height: 620,
      child: ProjectBoardsView(project: _project),
    ),
  ),
);

void main() {
  setUpAll(LocalDatabase.markUnavailable);

  // Borrando de verdad: `cleanState` no repone el estado inicial una vez
  // que el ViewModel ya cargó, y los tableros del test anterior quedarían.
  setUp(() async {
    await BoardsService.instance.notifier.ready;
    for (final board in [...BoardsService.instance.notifier.data.boards]) {
      BoardsService.instance.notifier.deleteBoard(board.id);
    }
    WorkspaceService.instance.notifier.cleanState();
  });

  group('sin ninguno', () {
    testWidgets('ofrece los dos caminos, no una explicación', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      expect(
        find.text('Este proyecto todavía no tiene tableros'),
        findsOneWidget,
      );
      expect(find.text('Pedírselo a Keel AI'), findsOneWidget);
      expect(find.text('Crearlo a mano'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lo que se le pide a Keel AI nombra el repo', (tester) async {
      final request = boardRequestFor(_project);
      expect(request, contains('aulamas-portal'));
      expect(request, contains('/tmp/aulamas-portal'));
    });
  });

  group('con tableros', () {
    testWidgets('una ficha por tablero, y entrar abre el suyo', (tester) async {
      _board('Lanzar oferta');
      _board('Push de prueba');

      await tester.pumpWidget(_app());
      await tester.pump();

      expect(find.text('Lanzar oferta'), findsOneWidget);
      expect(find.text('Push de prueba'), findsOneWidget);
      expect(find.text('2 tableros'), findsOneWidget);
      expect(find.text('Pedírselo a Keel AI'), findsNothing);

      await tester.tap(find.text('Lanzar oferta'));
      await tester.pump();

      final navigator = WorkspaceService.instance.notifier;
      expect(navigator.data.lens, WorkspaceLens.board);
      expect(navigator.data.boardId, 'board-Lanzar oferta');
    });

    testWidgets('borrar el último deja la pantalla que invita', (tester) async {
      _board('Lanzar oferta');

      await tester.pumpWidget(_app());
      await tester.pump();

      await tester.tap(find.byTooltip('Eliminar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('Lanzar oferta'), findsNothing);
      expect(
        find.text('Este proyecto todavía no tiene tableros'),
        findsOneWidget,
      );
    });
  });
}
