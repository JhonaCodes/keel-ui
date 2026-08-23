import 'dart:convert';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';

/// True if [a] and [b] serialize to the same JSON — used to skip rewriting
/// a record that hasn't actually changed since the last save.
bool _unchanged(Map<String, dynamic> a, Map<String, dynamic>? b) {
  if (b == null) return false;
  return jsonEncode(a) == jsonEncode(b);
}

/// Splits a project's tree (project → sessions → messages) across three key
/// namespaces instead of one document. A single session can accumulate tens of
/// MB of file-edit content across a few turns, well past the 16 MiB
/// per-record ceiling — decomposing keeps every record small regardless of
/// how much history a project's sessions carry.
class ProjectsRepository {
  static const _projectPrefix = 'project_';
  static const _sessionPrefixBase = 'session_';
  static const _msgPrefixBase = 'msg_';

  /// Hash del último mensaje escrito bajo cada clave.
  ///
  /// Un mensaje con ediciones de archivo lleva el contenido ENTERO de cada
  /// archivo, antes y después. Sin esto, cada turno preguntaba «¿cambió?»
  /// serializando los doscientos mensajes de la sesión —y los dos lados,
  /// porque [_unchanged] compara JSON contra JSON—: megabytes de basura por
  /// turno, con ocho miembros escribiendo a la vez. Eso es buena parte de lo
  /// que ponía la app pastosa mientras el workflow corría.
  ///
  /// El hash de un objeto Dart no paga eso: la VM cachea el de cada String,
  /// así que a partir de la segunda vez es aritmética. Se anota DESPUÉS de
  /// que la base confirmó, igual que el índice en memoria de [LocalDatabase]
  /// y por la misma razón: un fallo no puede dejar anotado que se escribió.
  ///
  /// Es estática porque el repositorio se instancia en cada acceso. Y el
  /// trato que acepta: una colisión de hash entre dos versiones del MISMO
  /// mensaje saltearía una escritura. Es aritméticamente despreciable, y lo
  /// que se perdería es el costo anotado en el último mensaje de un turno.
  static final Map<String, int> _writtenMessages = {};

  Future<List<Project>> load() async {
    final projectRecords = await LocalDatabase.getAllWithPrefix(_projectPrefix);
    final projects = <Project>[];
    for (final record in projectRecords) {
      projects.add(await _reassembleProject(record));
    }
    return projects;
  }

  Future<void> save(List<Project> projects) async {
    final projectIds = projects.map((project) => project.id).toSet();
    final existingProjectRecords = await LocalDatabase.getAllWithPrefix(
      _projectPrefix,
    );

    for (final project in projects) {
      await _persistProject(project);
    }

    for (final record in existingProjectRecords) {
      final id = record['id'] as String?;
      if (id == null || projectIds.contains(id)) continue;
      final staleSessionIds =
          (record['sessionIds'] as List?)?.cast<String>() ?? const [];
      await _deleteProject(id, staleSessionIds);
    }
  }

  Future<Project> _reassembleProject(Map<String, dynamic> projectRecord) async {
    final projectId = projectRecord['id'] as String;
    final sessionIds =
        (projectRecord['sessionIds'] as List?)?.cast<String>() ?? const [];

    final sessions = <Session>[];
    for (final sessionId in sessionIds) {
      final sessionKey = '$_sessionPrefixBase${projectId}_$sessionId';
      final sessionRecord = await LocalDatabase.get(sessionKey);
      if (sessionRecord == null) continue;
      sessions.add(await _reassembleSession(sessionId, sessionRecord));
    }

    final projectJson = Map<String, dynamic>.from(projectRecord)
      ..remove('sessionIds')
      ..['sessions'] = sessions.map((session) => session.toJson()).toList();
    return Project.fromJson(projectJson);
  }

  Future<Session> _reassembleSession(
    String sessionId,
    Map<String, dynamic> sessionRecord,
  ) async {
    final msgPrefix = '$_msgPrefixBase${sessionId}_';
    final msgRecords = await LocalDatabase.getAllWithPrefix(msgPrefix);
    msgRecords.sort((a, b) => (a['seq'] as int).compareTo(b['seq'] as int));

    final sessionJson = Map<String, dynamic>.from(sessionRecord)
      ..['messages'] = msgRecords
          .map((entry) => Map<String, dynamic>.from(entry)..remove('seq'))
          .toList();
    return Session.fromJson(sessionJson);
  }

  Future<void> _persistProject(Project project) async {
    final sessionIds = project.sessions.map((session) => session.id).toSet();
    final existingSessionRecords = await LocalDatabase.getAllWithPrefix(
      '$_sessionPrefixBase${project.id}_',
    );

    for (final session in project.sessions) {
      await _persistSession(project.id, session);
    }

    for (final record in existingSessionRecords) {
      final id = record['id'] as String?;
      if (id != null && !sessionIds.contains(id)) {
        await _deleteSession(project.id, id);
      }
    }

    final projectKey = '$_projectPrefix${project.id}';
    final projectJson = project.toJson()
      ..remove('sessions')
      ..['sessionIds'] = project.sessions.map((session) => session.id).toList();
    final existingProject = await LocalDatabase.get(projectKey);
    if (!_unchanged(projectJson, existingProject)) {
      await LocalDatabase.put(projectKey, projectJson);
    }
  }

  /// Only writes messages and the session record when their content actually
  /// changed — a session is re-saved on every turn, and rewriting every prior
  /// message (each potentially carrying full before/after file content)
  /// every time would multiply I/O for no reason.
  Future<void> _persistSession(String projectId, Session session) async {
    final msgPrefix = '$_msgPrefixBase${session.id}_';
    final existingMsgRecords = await LocalDatabase.getAllWithPrefix(msgPrefix);
    final existingBySeq = <int, Map<String, dynamic>>{
      for (final record in existingMsgRecords)
        if (record['seq'] is int) record['seq'] as int: record,
    };

    for (var index = 0; index < session.messages.length; index++) {
      final key = '$msgPrefix$index';
      final message = session.messages[index];
      final fingerprint = message.hashCode;
      if (_writtenMessages[key] == fingerprint) continue;

      final messageJson = message.toJson();
      messageJson['seq'] = index;
      if (!_unchanged(messageJson, existingBySeq[index])) {
        await LocalDatabase.put(key, messageJson);
      }
      _writtenMessages[key] = fingerprint;
    }

    for (final record in existingMsgRecords) {
      final seq = record['seq'] as int?;
      if (seq != null && seq >= session.messages.length) {
        await LocalDatabase.delete('$msgPrefix$seq');
        _writtenMessages.remove('$msgPrefix$seq');
      }
    }

    final sessionKey = '$_sessionPrefixBase${projectId}_${session.id}';
    final sessionJson = session.toJson()..remove('messages');
    final existingSession = await LocalDatabase.get(sessionKey);
    final existingSessionWithoutMessages = existingSession == null
        ? null
        : (Map<String, dynamic>.from(existingSession)..remove('messages'));
    if (!_unchanged(sessionJson, existingSessionWithoutMessages)) {
      await LocalDatabase.put(sessionKey, sessionJson);
    }
  }

  Future<void> _deleteProject(String projectId, List<String> sessionIds) async {
    for (final sessionId in sessionIds) {
      await _deleteSession(projectId, sessionId);
    }
    await LocalDatabase.delete('$_projectPrefix$projectId');
  }

  Future<void> _deleteSession(String projectId, String sessionId) async {
    final msgPrefix = '$_msgPrefixBase${sessionId}_';
    final msgRecords = await LocalDatabase.getAllWithPrefix(msgPrefix);
    for (final record in msgRecords) {
      await LocalDatabase.delete('$msgPrefix${record['seq']}');
    }
    _writtenMessages.removeWhere((key, _) => key.startsWith(msgPrefix));
    await LocalDatabase.delete('$_sessionPrefixBase${projectId}_$sessionId');
  }
}
