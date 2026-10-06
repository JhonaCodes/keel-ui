import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_core/modules/boards/model/board.dart';
import 'package:keel_core/modules/boards/model/board_run.dart';
import 'package:keel_core/modules/boards/service/boards_store.dart';
import 'package:keel_ui/src/core/services/store_mirror_view_model.dart';

export 'package:keel_core/modules/boards/model/board_run.dart' show BoardsState;

/// Thin mirror over [BoardsStore] (keel_core): the real catalog and
/// action-run logic lives there so keel-server can run it
/// without Flutter.
class BoardsViewModel extends StoreMirrorViewModel<BoardsState> {
  BoardsViewModel() : super(BoardsStore.instance);

  Future<void> get ready => BoardsStore.instance.ready;

  Board? boardById(String id) => BoardsStore.instance.boardById(id);

  Board? boardNamed(String projectId, String name) =>
      BoardsStore.instance.boardNamed(projectId, name);

  void upsert(Board board) => BoardsStore.instance.upsert(board);

  String? rename(String id, String name) =>
      BoardsStore.instance.rename(id, name);

  void deleteBoard(String id) => BoardsStore.instance.deleteBoard(id);

  void deleteBoardsOfProject(String projectId) =>
      BoardsStore.instance.deleteBoardsOfProject(projectId);

  Future<BoardRun?> run(
    String boardId,
    String actionId,
    Map<String, String> inputs,
  ) => BoardsStore.instance.run(boardId, actionId, inputs);
}

mixin BoardsService {
  static final ReactiveNotifier<BoardsViewModel> instance =
      ReactiveNotifier<BoardsViewModel>(() => BoardsViewModel());
}
