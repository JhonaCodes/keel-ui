import 'package:flutter_local_db/flutter_local_db.dart';
import 'package:logger_rs/logger_rs.dart';

import 'package:keel_ui/src/core/services/key_index.dart';

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
///
/// **La base se lee UNA vez y queda en memoria.** El paquete no tiene
/// consulta por prefijo: solo `GetById` (una clave) o `GetAll` (todo). Y
/// `GetAll` serializa la base entera a JSON, la cruza por FFI, la decodifica
/// y después re-serializa y re-parsea registro por registro — sin ceder el
/// hilo ni una vez. Llamarlo por cada consulta por prefijo era leer 5,5 MB
/// unas veinte veces seguidas para poder arrancar, con la UI congelada.
///
/// Que la copia en memoria pueda quedarse vieja no es un riesgo real acá:
/// este archivo es la única puerta a la base, y las sub-ventanas ni siquiera
/// escriben ([markUnavailable]). No hay quién la haga divergir.
///
/// Lo que sí cuesta es memoria: la base entera queda residente. Si algún día
/// molesta, la salida es podar los mensajes viejos — no volver a escanear.
class LocalDatabase {
  static const _migrationFlagKey = '_migrated_from_json_v1';

  static bool _initialized = false;
  static bool _unavailable = false;

  static KeyIndex? _index;
  static Future<KeyIndex>? _loading;

  /// Escrituras que ocurrieron mientras el índice se estaba cargando. Se
  /// aplican encima cuando llega, para que no se pierdan en la rendija.
  static final Map<String, Map<String, dynamic>?> _pending = {};

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
  static void markUnavailable() {
    _unavailable = true;
    _index = KeyIndex();
  }

  /// Whether this engine can actually persist. False in sub-windows.
  static bool get isAvailable => _initialized;

  /// El índice, cargándolo si hace falta.
  ///
  /// La memoización es la misma que usan los ViewModels para su `ready`: sin
  /// ella, los once catálogos que arrancan a la vez dispararían once lecturas
  /// completas en paralelo, que es exactamente lo que esto viene a evitar.
  static Future<KeyIndex> _ensureIndex() {
    final loaded = _index;
    if (loaded != null) return Future.value(loaded);
    return _loading ??= _load();
  }

  static Future<KeyIndex> _load() async {
    if (_unavailable) return _index = KeyIndex();

    final watch = Stopwatch()..start();
    final result = await LocalDB.GetAll();
    return result.when(
      ok: (models) {
        final index = KeyIndex({
          for (final model in models) model.id: model.data,
        });
        index.applyPending(_pending);
        _pending.clear();
        _index = index;
        Log.i(
          'Base local en memoria: ${index.length} registros en '
          '${watch.elapsedMilliseconds} ms',
        );
        return index;
      },
      err: (error) {
        _loading = null;
        Log.e('LocalDatabase could not read the database: $error');
        throw LocalDatabaseException(error.toString());
      },
    );
  }

  /// Anota el cambio en el índice, o lo guarda para cuando el índice llegue.
  ///
  /// Escribir NO fuerza la carga: una escritura temprana no tiene por qué
  /// pagar la lectura de toda la base.
  static void _remember(String key, Map<String, dynamic>? data) {
    final index = _index;
    if (index == null) {
      _pending[key] = data;
      return;
    }
    if (data == null) {
      index.remove(key);
    } else {
      index.put(key, data);
    }
  }

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
    // Después de que la base confirmó, nunca antes: una escritura que falla
    // no puede dejar el índice diciendo que salió bien.
    _remember(key, data);
  }

  static Future<Map<String, dynamic>?> get(String key) async {
    if (_unavailable) return null;
    return (await _ensureIndex()).get(key);
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
    _remember(key, null);
  }

  /// All records whose key starts with [prefix], in no particular order.
  static Future<List<Map<String, dynamic>>> getAllWithPrefix(
    String prefix,
  ) async {
    if (_unavailable) return const [];
    return (await _ensureIndex()).withPrefix(prefix);
  }

  /// Every record under [prefix] junto con SU CLAVE.
  ///
  /// [getAllWithPrefix] la descarta porque los repositorios la reconstruyen
  /// desde el `id` del payload. Una migración que renombra prefijos no
  /// puede: la clave vieja es justamente lo único que tiene para leer.
  static Future<List<({String key, Map<String, dynamic> data})>>
  entriesWithPrefix(String prefix) async {
    if (_unavailable) return const [];
    return (await _ensureIndex()).entriesWithPrefix(prefix);
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
