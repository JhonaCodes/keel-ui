import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/boards/model/board.dart';

class BoardsRepository {
  static const _prefix = 'board_';

  Future<List<Board>> load() async {
    final records = await LocalDatabase.getAllWithPrefix(_prefix);
    return records.map(Board.fromJson).toList();
  }

  Future<void> save(List<Board> boards) async {
    await LocalDatabase.replaceAllWithPrefix(
      _prefix,
      boards.map((board) => board.toJson()).toList(),
    );
  }
}
