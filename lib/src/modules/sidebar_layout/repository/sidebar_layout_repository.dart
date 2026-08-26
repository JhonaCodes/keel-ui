import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/sidebar_layout/model/sidebar_layout.dart';

class SidebarLayoutRepository {
  static const _prefix = 'sidebar_layout_';

  Future<List<SidebarLayout>> load() async {
    final records = await LocalDatabase.getAllWithPrefix(_prefix);
    return records.map(SidebarLayout.fromJson).toList();
  }

  Future<void> save(List<SidebarLayout> layouts) {
    return LocalDatabase.replaceAllWithPrefix(
      _prefix,
      layouts.map((layout) => layout.toJson()).toList(),
    );
  }
}
