import 'package:logger_rs/logger_rs.dart';

import 'package:keel_ui/src/core/services/local_database.dart';

/// Marca que el renombre ya corrió. Se escribe al final a propósito: mientras
/// no esté, los registros viejos siguen enteros y la migración vuelve a
/// intentarse en el próximo arranque. Eso, y no otra cosa, es la vuelta atrás.
const kStationsToProjectsFlagKey = '_migrated_stations_to_projects_v1';

const _oldProjectPrefix = 'station_';
const _newProjectPrefix = 'project_';
const _oldSessionPrefix = 'task_';
const _newSessionPrefix = 'session_';

/// Lo único que la migración necesita de la base.
///
/// Existe para poder inyectarla: es la parte del sistema que puede perder
/// datos del usuario, y probarla contra LMDB de verdad no se puede.
abstract interface class MigrationStore {
  Future<List<({String key, Map<String, dynamic> data})>> entries(
    String prefix,
  );
  Future<Map<String, dynamic>?> get(String key);
  Future<void> put(String key, Map<String, dynamic> data);
  Future<void> delete(String key);
}

class LocalDatabaseMigrationStore implements MigrationStore {
  const LocalDatabaseMigrationStore();

  @override
  Future<List<({String key, Map<String, dynamic> data})>> entries(
    String prefix,
  ) => LocalDatabase.entriesWithPrefix(prefix);

  @override
  Future<Map<String, dynamic>?> get(String key) => LocalDatabase.get(key);

  @override
  Future<void> put(String key, Map<String, dynamic> data) =>
      LocalDatabase.put(key, data);

  @override
  Future<void> delete(String key) => LocalDatabase.delete(key);
}

/// La estación pasó a llamarse proyecto y su tarea, sesión. Esto renombra las
/// claves de la base para que los datos que ya tenías sigan estando.
///
/// **Escribe, verifica y recién ahí borra.** Escribir es idempotente porque
/// los ids no cambian: una corrida cortada a la mitad no duplica nada, la
/// segunda escribe lo mismo encima. Y si la verificación no cierra, no se
/// borra nada y no se pone la bandera — se reintenta solo.
///
/// Las claves de los mensajes (`msg_<sesión>_<n>`) no se tocan: llevan el id
/// de la sesión, que es el mismo de siempre. Lo único que cambia adentro del
/// payload son dos nombres de campo que el renombre arrastró.
Future<void> migrateStationsToProjects({MigrationStore? store}) async {
  final db = store ?? const LocalDatabaseMigrationStore();
  if (await db.get(kStationsToProjectsFlagKey) != null) return;

  final oldProjects = await db.entries(_oldProjectPrefix);
  final oldSessions = await db.entries(_oldSessionPrefix);

  if (oldProjects.isEmpty && oldSessions.isEmpty) {
    await _mark(db, 0, 0);
    return;
  }

  for (final entry in oldProjects) {
    await db.put(
      '$_newProjectPrefix${entry.key.substring(_oldProjectPrefix.length)}',
      renamedProjectPayload(entry.data),
    );
  }
  for (final entry in oldSessions) {
    await db.put(
      '$_newSessionPrefix${entry.key.substring(_oldSessionPrefix.length)}',
      entry.data,
    );
  }

  final newProjects = await db.entries(_newProjectPrefix);
  final newSessions = await db.entries(_newSessionPrefix);
  if (newProjects.length < oldProjects.length ||
      newSessions.length < oldSessions.length) {
    Log.e(
      'La migración a proyectos escribió de menos '
      '(${newProjects.length}/${oldProjects.length} proyectos, '
      '${newSessions.length}/${oldSessions.length} sesiones). '
      'No se borra nada y se reintenta en el próximo arranque.',
    );
    return;
  }

  for (final entry in [...oldProjects, ...oldSessions]) {
    await db.delete(entry.key);
  }

  await _mark(db, oldProjects.length, oldSessions.length);
}

/// El registro de un proyecto con los dos campos que el renombre movió.
///
/// El resto del payload no se toca: cuanto menos transforme esto, menos
/// puede romper.
Map<String, dynamic> renamedProjectPayload(Map<String, dynamic> data) {
  final renamed = Map<String, dynamic>.from(data);
  if (renamed.containsKey('taskIds')) {
    renamed['sessionIds'] = renamed.remove('taskIds');
  }
  if (renamed.containsKey('activeTaskId')) {
    renamed['activeSessionId'] = renamed.remove('activeTaskId');
  }
  return renamed;
}

Future<void> _mark(MigrationStore db, int projects, int sessions) async {
  await db.put(kStationsToProjectsFlagKey, {
    'migratedAt': DateTime.now().toIso8601String(),
    'projects': projects,
    'sessions': sessions,
  });
  if (projects > 0 || sessions > 0) {
    Log.i('Migrados $projects proyectos y $sessions sesiones al nombre nuevo.');
  }
}
