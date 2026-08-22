import 'dart:async';

import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/integrations/genui/genui.dart';
import 'package:keel_ui/src/modules/boards/model/board.dart';
import 'package:keel_ui/src/modules/boards/model/board_run.dart';
import 'package:keel_ui/src/modules/boards/repository/board_runs_repository.dart';
import 'package:keel_ui/src/modules/boards/repository/boards_repository.dart';
import 'package:keel_ui/src/modules/secrets/viewmodel/secrets_viewmodel.dart';

class BoardsViewModel extends ViewModel<BoardsState> {
  BoardsViewModel() : super(const BoardsState());

  BoardsRepository get _repository => BoardsRepository();
  BoardRunsRepository get _runs => BoardRunsRepository();

  Future<void>? _ready;
  Future<void> get ready => _ready ??= _loadPersisted();

  @override
  void init() {
    if (_ready == null) updateSilently(const BoardsState());
    unawaited(ready);
  }

  Future<void> _loadPersisted() async {
    try {
      final boards = await _repository.load();
      final runs = await _runs.load();
      updateState(data.copyWith(boards: boards, runs: runs));
    } catch (error) {
      Log.e('Failed to load persisted boards', error: error);
    }
  }

  Board? boardById(String id) =>
      data.boards.where((board) => board.id == id).firstOrNull;

  Board? boardNamed(String projectId, String name) => data.boards
      .where((board) => board.projectId == projectId && board.name == name)
      .firstOrNull;

  /// Guarda un tablero que ya viene armado y validado por [parseBoardSpec].
  /// Es idempotente por NOMBRE dentro del proyecto: pedir dos veces el mismo
  /// tablero lo actualiza en vez de dejar dos que se llaman igual.
  void upsert(Board board) {
    final existing = boardNamed(board.projectId, board.name);
    final boards = existing == null
        ? [...data.boards, board]
        : [
            for (final current in data.boards)
              if (current.id == existing.id) board else current,
          ];
    updateState(data.copyWith(boards: boards));
    unawaited(_repository.save(boards));
  }

  String? rename(String id, String name) {
    final board = boardById(id);
    if (board == null) return 'Ese tablero ya no existe.';
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'El nombre no puede estar vacío.';

    final taken = data.boards.any(
      (other) =>
          other.id != id &&
          other.projectId == board.projectId &&
          other.name == trimmed,
    );
    if (taken) return 'Ya hay un tablero con ese nombre en este proyecto.';

    final boards = [
      for (final current in data.boards)
        if (current.id == id)
          current.copyWith(name: trimmed, updatedAt: DateTime.now())
        else
          current,
    ];
    updateState(data.copyWith(boards: boards));
    unawaited(_repository.save(boards));
    return null;
  }

  void deleteBoard(String id) {
    final boards = data.boards.where((board) => board.id != id).toList();
    final runs = {...data.runs};
    final removed = runs.remove(id) ?? const <BoardRun>[];
    updateState(data.copyWith(boards: boards, runs: runs));
    unawaited(_repository.save(boards));
    unawaited(_runs.forgetBoard(removed));
  }

  /// Los tableros de un proyecto que se borra. El proyecto se lleva sus
  /// tableros: sin su directorio de trabajo no prueban nada.
  void deleteBoardsOfProject(String projectId) {
    for (final board in data.forProject(projectId)) {
      deleteBoard(board.id);
    }
  }

  /// Dispara una acción y guarda cómo fue.
  ///
  /// [inputs] son los valores que escribiste. Los campos de tipo secreto no
  /// vienen de ahí: se resuelven acá contra el catálogo de secrets, así el
  /// valor no pasa por la UI ni queda en la corrida guardada.
  Future<BoardRun?> run(
    String boardId,
    String actionId,
    Map<String, String> inputs,
  ) async {
    final board = boardById(boardId);
    if (board == null || data.running.contains(boardId)) return null;
    final action = board.actions
        .where((candidate) => candidate.id == actionId)
        .firstOrNull;
    if (action == null) return null;

    final secrets = SecretsService.instance.notifier;
    final values = <String, String>{
      ...inputs,
      for (final field in board.fields)
        if (field.kind == BoardFieldKind.secreto)
          field.key:
              secrets.valuesFor([field.secretName])[field.secretName] ?? '',
    };

    updateState(data.copyWith(running: {...data.running, boardId}));
    try {
      final run = await runBoardAction(
        board: board,
        action: action,
        values: values,
      );
      _remember(run);
      return run;
    } finally {
      updateState(data.copyWith(running: {...data.running}..remove(boardId)));
    }
  }

  void _remember(BoardRun run) {
    final forBoard = [run, ...?data.runs[run.boardId]];
    updateState(
      data.copyWith(
        runs: {
          ...data.runs,
          run.boardId: forBoard.take(BoardRunsRepository.keptPerBoard).toList(),
        },
      ),
    );
    unawaited(_runs.save(run));
    unawaited(_runs.prune(forBoard));
  }
}

mixin BoardsService {
  static final ReactiveNotifier<BoardsViewModel> instance =
      ReactiveNotifier<BoardsViewModel>(() => BoardsViewModel());
}
