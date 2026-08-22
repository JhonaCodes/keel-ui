import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/boards/model/board_run.dart';

/// Las corridas de cada tablero, con el id del tablero adentro de la clave.
///
/// Prefijo propio y **fuera del respaldo**: la definición de un tablero es
/// algo que compartís; lo que te contestó tu API de desarrollo el martes no
/// le sirve a nadie más, y restaurarlo en otra máquina sería historia
/// prestada. Mismo criterio que los probes de MCP y las tomas de tareas.
class BoardRunsRepository {
  static const _prefix = 'boardrun_';

  /// Cuántas se guardan por tablero. Probar es comparar —"antes daba 201 y
  /// ahora 500"— pero con veinte alcanza y de paso la base no crece sola.
  static const keptPerBoard = 20;

  String _keyFor(BoardRun run) => '$_prefix${run.boardId}_${run.id}';

  Future<Map<String, List<BoardRun>>> load() async {
    final records = await LocalDatabase.getAllWithPrefix(_prefix);
    final byBoard = <String, List<BoardRun>>{};
    for (final record in records) {
      final run = BoardRun.fromJson(record);
      byBoard.putIfAbsent(run.boardId, () => []).add(run);
    }
    for (final runs in byBoard.values) {
      runs.sort((a, b) => b.at.compareTo(a.at));
    }
    return byBoard;
  }

  Future<void> save(BoardRun run) =>
      LocalDatabase.put(_keyFor(run), run.toJson());

  /// Borra las que sobran de un tablero, de la más vieja a la más nueva.
  Future<void> prune(List<BoardRun> newestFirst) async {
    for (final run in newestFirst.skip(keptPerBoard)) {
      await LocalDatabase.delete(_keyFor(run));
    }
  }

  Future<void> forgetBoard(List<BoardRun> runs) async {
    for (final run in runs) {
      await LocalDatabase.delete(_keyFor(run));
    }
  }
}
