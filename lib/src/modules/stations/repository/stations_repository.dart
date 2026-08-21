import 'dart:convert';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/stations/model/station.dart';
import 'package:keel_ui/src/modules/stations/model/station_task.dart';

/// True if [a] and [b] serialize to the same JSON — used to skip rewriting
/// a record that hasn't actually changed since the last save.
bool _unchanged(Map<String, dynamic> a, Map<String, dynamic>? b) {
  if (b == null) return false;
  return jsonEncode(a) == jsonEncode(b);
}

/// Splits a station's tree (station → tasks → messages) across three key
/// namespaces instead of one document. A single task can accumulate tens of
/// MB of file-edit content across a few turns, well past the 16 MiB
/// per-record ceiling — decomposing keeps every record small regardless of
/// how much history a station's tasks carry.
class StationsRepository {
  static const _stationPrefix = 'station_';
  static const _taskPrefixBase = 'task_';
  static const _msgPrefixBase = 'msg_';

  Future<List<Station>> load() async {
    final stationRecords = await LocalDatabase.getAllWithPrefix(_stationPrefix);
    final stations = <Station>[];
    for (final record in stationRecords) {
      stations.add(await _reassembleStation(record));
    }
    return stations;
  }

  Future<void> save(List<Station> stations) async {
    final stationIds = stations.map((station) => station.id).toSet();
    final existingStationRecords = await LocalDatabase.getAllWithPrefix(
      _stationPrefix,
    );

    for (final station in stations) {
      await _persistStation(station);
    }

    for (final record in existingStationRecords) {
      final id = record['id'] as String?;
      if (id == null || stationIds.contains(id)) continue;
      final staleTaskIds =
          (record['taskIds'] as List?)?.cast<String>() ?? const [];
      await _deleteStation(id, staleTaskIds);
    }
  }

  Future<Station> _reassembleStation(Map<String, dynamic> stationRecord) async {
    final stationId = stationRecord['id'] as String;
    final taskIds =
        (stationRecord['taskIds'] as List?)?.cast<String>() ?? const [];

    final tasks = <StationTask>[];
    for (final taskId in taskIds) {
      final taskKey = '$_taskPrefixBase${stationId}_$taskId';
      final taskRecord = await LocalDatabase.get(taskKey);
      if (taskRecord == null) continue;
      tasks.add(await _reassembleTask(taskId, taskRecord));
    }

    final stationJson = Map<String, dynamic>.from(stationRecord)
      ..remove('taskIds')
      ..['tasks'] = tasks.map((task) => task.toJson()).toList();
    return Station.fromJson(stationJson);
  }

  Future<StationTask> _reassembleTask(
    String taskId,
    Map<String, dynamic> taskRecord,
  ) async {
    final msgPrefix = '$_msgPrefixBase${taskId}_';
    final msgRecords = await LocalDatabase.getAllWithPrefix(msgPrefix);
    msgRecords.sort((a, b) => (a['seq'] as int).compareTo(b['seq'] as int));

    final taskJson = Map<String, dynamic>.from(taskRecord)
      ..['messages'] = msgRecords
          .map((entry) => Map<String, dynamic>.from(entry)..remove('seq'))
          .toList();
    return StationTask.fromJson(taskJson);
  }

  Future<void> _persistStation(Station station) async {
    final taskIds = station.tasks.map((task) => task.id).toSet();
    final existingTaskRecords = await LocalDatabase.getAllWithPrefix(
      '$_taskPrefixBase${station.id}_',
    );

    for (final task in station.tasks) {
      await _persistTask(station.id, task);
    }

    for (final record in existingTaskRecords) {
      final id = record['id'] as String?;
      if (id != null && !taskIds.contains(id)) {
        await _deleteTask(station.id, id);
      }
    }

    final stationKey = '$_stationPrefix${station.id}';
    final stationJson = station.toJson()
      ..remove('tasks')
      ..['taskIds'] = station.tasks.map((task) => task.id).toList();
    final existingStation = await LocalDatabase.get(stationKey);
    if (!_unchanged(stationJson, existingStation)) {
      await LocalDatabase.put(stationKey, stationJson);
    }
  }

  /// Only writes messages and the task record when their content actually
  /// changed — a task is re-saved on every turn, and rewriting every prior
  /// message (each potentially carrying full before/after file content)
  /// every time would multiply I/O for no reason.
  Future<void> _persistTask(String stationId, StationTask task) async {
    final msgPrefix = '$_msgPrefixBase${task.id}_';
    final existingMsgRecords = await LocalDatabase.getAllWithPrefix(msgPrefix);
    final existingBySeq = <int, Map<String, dynamic>>{
      for (final record in existingMsgRecords)
        if (record['seq'] is int) record['seq'] as int: record,
    };

    for (var index = 0; index < task.messages.length; index++) {
      final messageJson = task.messages[index].toJson();
      messageJson['seq'] = index;
      if (_unchanged(messageJson, existingBySeq[index])) continue;
      await LocalDatabase.put('$msgPrefix$index', messageJson);
    }

    for (final record in existingMsgRecords) {
      final seq = record['seq'] as int?;
      if (seq != null && seq >= task.messages.length) {
        await LocalDatabase.delete('$msgPrefix$seq');
      }
    }

    final taskKey = '$_taskPrefixBase${stationId}_${task.id}';
    final taskJson = task.toJson()..remove('messages');
    final existingTask = await LocalDatabase.get(taskKey);
    final existingTaskWithoutMessages = existingTask == null
        ? null
        : (Map<String, dynamic>.from(existingTask)..remove('messages'));
    if (!_unchanged(taskJson, existingTaskWithoutMessages)) {
      await LocalDatabase.put(taskKey, taskJson);
    }
  }

  Future<void> _deleteStation(String stationId, List<String> taskIds) async {
    for (final taskId in taskIds) {
      await _deleteTask(stationId, taskId);
    }
    await LocalDatabase.delete('$_stationPrefix$stationId');
  }

  Future<void> _deleteTask(String stationId, String taskId) async {
    final msgPrefix = '$_msgPrefixBase${taskId}_';
    final msgRecords = await LocalDatabase.getAllWithPrefix(msgPrefix);
    for (final record in msgRecords) {
      await LocalDatabase.delete('$msgPrefix${record['seq']}');
    }
    await LocalDatabase.delete('$_taskPrefixBase${stationId}_$taskId');
  }
}
