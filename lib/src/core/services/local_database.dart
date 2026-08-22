import 'package:flutter_local_db/flutter_local_db.dart';
import 'package:logger_rs/logger_rs.dart';

/// Thrown when a database operation fails. Repositories let this propagate
/// exactly like the file-based repositories they replace let I/O exceptions
/// propagate — callers already catch and log at the ViewModel layer.
class LocalDatabaseException implements Exception {
  final String message;

  const LocalDatabaseException(this.message);

  @override
  String toString() => 'LocalDatabaseException: $message';
}

/// The only file in this project that imports `flutter_local_db`. Every
/// repository goes through this key-value wrapper so the storage backend
/// stays swappable and no module needs to know about `LocalDbResult`.
class LocalDatabase {
  static const _migrationFlagKey = '_migrated_from_json_v1';

  static bool _initialized = false;
  static bool _unavailable = false;

  LocalDatabase._();

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    await LocalDB.init();
    _initialized = true;
  }

  /// Declares that THIS engine has no storage, on purpose.
  ///
  /// Every sub-window is a separate Flutter engine, and each one opening
  /// its own LMDB handle is exactly what the main window's init avoids —
  /// so sub-windows never initialize the database. But their ViewModels
  /// are the same `reactive_notifier` singletons, and they self-init on
  /// first touch: a chat bubble reading the font scale reaches
  /// `SettingsRepository`, which reaches here.
  ///
  /// With this flag, reads answer "nothing stored" and writes are dropped
  /// — a stated contract, not a swallowed failure. Without it (main
  /// engine), an uninitialized database still throws, because there the
  /// same call really is a bug.
  static void markUnavailable() => _unavailable = true;

  /// Whether this engine can actually persist. False in sub-windows.
  static bool get isAvailable => _initialized;

  static Future<void> put(String key, Map<String, dynamic> data) async {
    if (_unavailable) return;
    final result = await LocalDB.Put(key, data);
    result.when(
      ok: (_) {},
      err: (error) {
        Log.e('LocalDatabase.put($key) failed: $error');
        throw LocalDatabaseException(error.toString());
      },
    );
  }

  static Future<Map<String, dynamic>?> get(String key) async {
    if (_unavailable) return null;
    final result = await LocalDB.GetById(key);
    return result.when(
      ok: (model) => model?.data,
      err: (error) {
        Log.e('LocalDatabase.get($key) failed: $error');
        throw LocalDatabaseException(error.toString());
      },
    );
  }

  static Future<void> delete(String key) async {
    if (_unavailable) return;
    final result = await LocalDB.Delete(key);
    result.when(
      ok: (_) {},
      err: (error) {
        Log.e('LocalDatabase.delete($key) failed: $error');
        throw LocalDatabaseException(error.toString());
      },
    );
  }

  /// All records whose key starts with [prefix], in no particular order.
  static Future<List<Map<String, dynamic>>> getAllWithPrefix(
    String prefix,
  ) async {
    if (_unavailable) return const [];
    final result = await LocalDB.GetAll();
    return result.when(
      ok: (models) => models
          .where((model) => model.id.startsWith(prefix))
          .map((model) => model.data)
          .toList(),
      err: (error) {
        Log.e('LocalDatabase.getAllWithPrefix($prefix) failed: $error');
        throw LocalDatabaseException(error.toString());
      },
    );
  }

  /// Every record under [prefix] junto con SU CLAVE.
  ///
  /// [getAllWithPrefix] la descarta porque los repositorios la reconstruyen
  /// desde el `id` del payload. Una migración que renombra prefijos no
  /// puede: la clave vieja es justamente lo único que tiene para leer.
  static Future<List<({String key, Map<String, dynamic> data})>>
  entriesWithPrefix(String prefix) async {
    if (_unavailable) return const [];
    final result = await LocalDB.GetAll();
    return result.when(
      ok: (models) => models
          .where((model) => model.id.startsWith(prefix))
          .map((model) => (key: model.id, data: model.data))
          .toList(),
      err: (error) {
        Log.e('LocalDatabase.entriesWithPrefix($prefix) failed: $error');
        throw LocalDatabaseException(error.toString());
      },
    );
  }

  /// Replaces every record under [prefix] with exactly [items] — upserts
  /// each one (each map must carry an `id` field), then deletes whatever
  /// was under that prefix and is no longer present. Mirrors the "overwrite
  /// the whole file" semantics of the single-file JSON repository it
  /// replaces.
  static Future<void> replaceAllWithPrefix(
    String prefix,
    List<Map<String, dynamic>> items,
  ) async {
    if (_unavailable) return;
    final currentIds = items.map((item) => item['id'] as String).toSet();
    final existing = await getAllWithPrefix(prefix);

    for (final item in items) {
      await put('$prefix${item['id']}', item);
    }
    for (final record in existing) {
      final id = record['id'] as String?;
      if (id != null && !currentIds.contains(id)) {
        await delete('$prefix$id');
      }
    }
  }

  static Future<bool> hasMigrated() async {
    return await get(_migrationFlagKey) != null;
  }

  static Future<void> markMigrated() async {
    await put(_migrationFlagKey, {
      'migratedAt': DateTime.now().toIso8601String(),
    });
  }
}
