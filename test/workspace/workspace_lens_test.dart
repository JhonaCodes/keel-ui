import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/boards/model/board.dart';
import 'package:keel_ui/src/modules/boards/viewmodel/boards_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/workspace/model/workspace_lens.dart';
import 'package:keel_ui/src/modules/workspace/viewmodel/workspace_viewmodel.dart';

final _epoch = DateTime(2026, 8, 23);

String _project(String name) {
  final projects = ProjectsService.instance.notifier;
  projects.createProject(
    name: name,
    purpose: '',
    workingDirectory: '/tmp/$name',
    profileIds: const [],
    workflowIds: const [],
    ruleNames: const [],
    knowledgeBaseNames: const [],
  );
  return projects.data.projects.firstWhere((entry) => entry.name == name).id;
}

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

  group('abrir algo mueve la selección Y el lente', () {
    test('una sesión, estando en un tablero', () {
      final navigator = WorkspaceService.instance.notifier;
      final projects = ProjectsService.instance.notifier;
      final projectId = _project('portal');
      navigator.openNewSession(projectId);
      final sessionId = projects.data.projects.single.activeSessionId!;

      navigator.openBoard('tablero-1');
      expect(navigator.data.lens, WorkspaceLens.board);

      // La regresión: esto movía `activeSessionId` y dejaba el lente en el
      // tablero, así que tocar la sesión no llevaba a ningún lado.
      navigator.openSession(projectId, sessionId);
      expect(navigator.data.lens, WorkspaceLens.session);
      expect(navigator.data.boardId, isNull);
      expect(projects.data.projects.single.activeSessionId, sessionId);
    });

    test('el estado del proyecto cierra la sesión abierta', () {
      final navigator = WorkspaceService.instance.notifier;
      final projects = ProjectsService.instance.notifier;
      final projectId = _project('portal');
      navigator.openNewSession(projectId);

      navigator.openProjectState(projectId);
      expect(navigator.data.lens, WorkspaceLens.projectState);
      expect(projects.data.projects.single.activeSessionId, isNull);
    });

    test('los tableros no cierran nada: la sesión sigue abierta detrás', () {
      final navigator = WorkspaceService.instance.notifier;
      final projects = ProjectsService.instance.notifier;
      final projectId = _project('portal');
      navigator.openNewSession(projectId);
      final sessionId = projects.data.projects.single.activeSessionId;

      navigator.openBoards(projectId);
      expect(navigator.data.lens, WorkspaceLens.boards);
      expect(projects.data.projects.single.activeSessionId, sessionId);
    });

    test('un proyecto vuelve a donde lo dejaste', () {
      final navigator = WorkspaceService.instance.notifier;
      final conSesion = _project('portal');
      final sinSesion = _project('api');
      navigator.openNewSession(conSesion);

      navigator.openProject(sinSesion);
      expect(navigator.data.lens, WorkspaceLens.projectState);

      navigator.openProject(conSesion);
      expect(navigator.data.lens, WorkspaceLens.session);
    });
  });

  group('el id del tablero no sobrevive al lente', () {
    test('cambiar de lente lo suelta', () {
      final navigator = WorkspaceService.instance.notifier;
      final projectId = _project('portal');

      navigator.openBoard('tablero-1');
      expect(navigator.data.boardId, 'tablero-1');

      navigator.openBoards(projectId);
      expect(navigator.data.boardId, isNull);
    });

    test('pedir el mismo lente dos veces igual limpia el id', () {
      final navigator = WorkspaceService.instance.notifier;
      final projectId = _project('portal');

      navigator.openProjectState(projectId);
      navigator.openBoard('tablero-1');
      navigator.openProjectState(projectId);
      expect(navigator.data.lens, WorkspaceLens.projectState);
      expect(navigator.data.boardId, isNull);
    });
  });

  group('qué lentes son del proyecto', () {
    test('los cuatro de adentro sí, los dos de afuera no', () {
      const dentro = [
        WorkspaceLens.projectState,
        WorkspaceLens.boards,
        WorkspaceLens.board,
        WorkspaceLens.session,
      ];
      for (final lens in WorkspaceLens.values) {
        expect(
          WorkspaceState(lens: lens).isProjectScoped,
          dentro.contains(lens),
          reason: '$lens',
        );
      }
    });
  });

  group('el lente cae solo cuando lo que miraba ya no está', () {
    test('un tablero borrado deja la lista, no un hueco', () {
      const abierto = WorkspaceState(lens: WorkspaceLens.board, boardId: 'b1');
      expect(abierto.resolved(boardExists: true), WorkspaceLens.board);
      expect(abierto.resolved(boardExists: false), WorkspaceLens.boards);
    });

    test('los otros lentes no dependen de eso', () {
      for (final lens in WorkspaceLens.values) {
        if (lens == WorkspaceLens.board) continue;
        expect(WorkspaceState(lens: lens).resolved(boardExists: false), lens);
      }
    });
  });

  group('borrar un tablero', () {
    test('lo saca de la lista y no vuelve', () {
      final boards = BoardsService.instance.notifier;
      final board = Board(
        id: 'b1',
        projectId: 'p1',
        name: 'Lanzar oferta',
        createdAt: _epoch,
        updatedAt: _epoch,
      );
      boards.upsert(board);
      expect(boards.data.forProject('p1'), hasLength(1));

      boards.deleteBoard('b1');
      expect(boards.data.forProject('p1'), isEmpty);
      expect(boards.boardById('b1'), isNull);
    });
  });
}
