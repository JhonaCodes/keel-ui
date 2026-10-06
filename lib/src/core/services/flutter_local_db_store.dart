import 'package:keel_core/core/store/keel_store.dart';

import 'package:keel_ui/src/core/services/local_database.dart';

/// The `keel_core` [KeelStore] implementation backed by this app's
/// `flutter_local_db`-based [LocalDatabase]. Wired into [KeelStore.instance]
/// once at startup, before any repository moved to `keel_core` touches it.
class FlutterLocalDbStore implements KeelStore {
  const FlutterLocalDbStore();

  @override
  Future<void> put(String key, Map<String, dynamic> data) =>
      LocalDatabase.put(key, data);

  @override
  Future<Map<String, dynamic>?> get(String key) => LocalDatabase.get(key);

  @override
  Future<void> delete(String key) => LocalDatabase.delete(key);

  @override
  Future<List<Map<String, dynamic>>> getAllWithPrefix(String prefix) =>
      LocalDatabase.getAllWithPrefix(prefix);

  @override
  Future<List<({String key, Map<String, dynamic> data})>> entriesWithPrefix(
    String prefix,
  ) => LocalDatabase.entriesWithPrefix(prefix);

  @override
  Future<void> replaceAllWithPrefix(
    String prefix,
    List<Map<String, dynamic>> items,
  ) => LocalDatabase.replaceAllWithPrefix(prefix, items);
}
