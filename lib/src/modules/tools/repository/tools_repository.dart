import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/tools/model/tool.dart';

class ToolsRepository {
  static const _prefix = 'tool_';

  Future<List<Tool>> load() async {
    final records = await LocalDatabase.getAllWithPrefix(_prefix);
    return records.map(Tool.fromJson).toList();
  }

  Future<void> save(List<Tool> tools) async {
    await LocalDatabase.replaceAllWithPrefix(
      _prefix,
      tools.map((tool) => tool.toJson()).toList(),
    );
  }
}
