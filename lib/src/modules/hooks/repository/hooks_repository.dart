import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/hooks/model/hook.dart';

class HooksRepository {
  static const _prefix = 'hook_';

  Future<List<Hook>> load() async {
    final records = await LocalDatabase.getAllWithPrefix(_prefix);
    return records.map(Hook.fromJson).toList();
  }

  Future<void> save(List<Hook> hooks) async {
    await LocalDatabase.replaceAllWithPrefix(
      _prefix,
      hooks.map((hook) => hook.toJson()).toList(),
    );
  }
}
