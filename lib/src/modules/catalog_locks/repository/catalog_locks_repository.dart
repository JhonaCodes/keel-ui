import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/catalog_locks/model/catalog_lock.dart';

class CatalogLocksRepository {
  static const _prefix = 'catalog_lock_';

  Future<List<CatalogLock>> load() async {
    final records = await LocalDatabase.getAllWithPrefix(_prefix);
    return records.map(CatalogLock.fromJson).toList();
  }

  Future<void> save(List<CatalogLock> locks) =>
      LocalDatabase.replaceAllWithPrefix(
        _prefix,
        locks.map((lock) => lock.toJson()).toList(),
      );
}
