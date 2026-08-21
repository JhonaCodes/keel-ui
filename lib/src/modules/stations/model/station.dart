import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/modules/stations/model/station_task.dart';

final RegExp _stationNameFormat = RegExp(r'^[a-z0-9_-]{1,24}$');

/// Returns a human error message if [value] can't be used as a [Station.name],
/// or null if it's valid. Same channel-handle shape as an agent profile name,
/// just a little longer — it reads as `#mobile-con-dev` in the UI.
String? validateStationName(String value) {
  if (value.isEmpty) return 'El nombre no puede estar vacío.';
  if (value.length > 24) return 'Máximo 24 caracteres.';
  if (value.contains(' ')) return 'No se permiten espacios.';
  if (value != value.toLowerCase()) return 'Usa solo minúsculas.';
  if (!_stationNameFormat.hasMatch(value)) {
    return 'Solo letras minúsculas, números, "-" y "_".';
  }
  return null;
}

/// A durable workspace: the agents that live in it, the workflows that decide
/// who acts and when, plus the rules and documents they all share. Tasks come
/// and go inside it — the station itself is configured once and stays.
class Station {
  final String id;
  final String name;
  final String purpose;
  final String workingDirectory;
  final List<String> profileIds;
  final List<String> workflowIds;
  final List<String> ruleNames;
  final List<String> documentPaths;
  final String? activeWorkflowId;
  final List<StationTask> tasks;
  final String? activeTaskId;
  final DateTime createdAt;

  const Station({
    required this.id,
    required this.name,
    required this.purpose,
    required this.workingDirectory,
    required this.createdAt,
    this.profileIds = const [],
    this.workflowIds = const [],
    this.ruleNames = const [],
    this.documentPaths = const [],
    this.activeWorkflowId,
    this.tasks = const [],
    this.activeTaskId,
  });

  StationTask? get activeTask {
    final id = activeTaskId;
    if (id == null) return null;
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  Station copyWith({
    String? name,
    String? purpose,
    String? workingDirectory,
    List<String>? profileIds,
    List<String>? workflowIds,
    List<String>? ruleNames,
    List<String>? documentPaths,
    String? activeWorkflowId,
    bool clearActiveWorkflow = false,
    List<StationTask>? tasks,
    String? activeTaskId,
    bool clearActiveTask = false,
  }) {
    return Station(
      id: id,
      name: name ?? this.name,
      purpose: purpose ?? this.purpose,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      profileIds: profileIds ?? this.profileIds,
      workflowIds: workflowIds ?? this.workflowIds,
      ruleNames: ruleNames ?? this.ruleNames,
      documentPaths: documentPaths ?? this.documentPaths,
      activeWorkflowId: clearActiveWorkflow
          ? null
          : (activeWorkflowId ?? this.activeWorkflowId),
      tasks: tasks ?? this.tasks,
      activeTaskId: clearActiveTask
          ? null
          : (activeTaskId ?? this.activeTaskId),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'purpose': purpose,
    'workingDirectory': workingDirectory,
    'profileIds': profileIds,
    'workflowIds': workflowIds,
    'ruleNames': ruleNames,
    'documentPaths': documentPaths,
    'activeWorkflowId': activeWorkflowId,
    'tasks': tasks.map((task) => task.toJson()).toList(),
    'activeTaskId': activeTaskId,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['id'] as String,
      name: json['name'] as String,
      purpose: json['purpose'] as String? ?? '',
      workingDirectory: json['workingDirectory'] as String,
      profileIds: (json['profileIds'] as List?)?.cast<String>() ?? const [],
      workflowIds: (json['workflowIds'] as List?)?.cast<String>() ?? const [],
      ruleNames: (json['ruleNames'] as List?)?.cast<String>() ?? const [],
      documentPaths:
          (json['documentPaths'] as List?)?.cast<String>() ?? const [],
      activeWorkflowId: json['activeWorkflowId'] as String?,
      tasks: (json['tasks'] as List? ?? const [])
          .map((entry) => StationTask.fromJson(entry as Map<String, dynamic>))
          .toList(),
      activeTaskId: json['activeTaskId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Station &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          purpose == other.purpose &&
          workingDirectory == other.workingDirectory &&
          listEquals(profileIds, other.profileIds) &&
          listEquals(workflowIds, other.workflowIds) &&
          listEquals(ruleNames, other.ruleNames) &&
          listEquals(documentPaths, other.documentPaths) &&
          activeWorkflowId == other.activeWorkflowId &&
          listEquals(tasks, other.tasks) &&
          activeTaskId == other.activeTaskId &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    purpose,
    workingDirectory,
    Object.hashAll(profileIds),
    Object.hashAll(workflowIds),
    Object.hashAll(ruleNames),
    Object.hashAll(documentPaths),
    activeWorkflowId,
    Object.hashAll(tasks),
    activeTaskId,
    createdAt,
  );

  @override
  String toString() =>
      'Station(id: $id, name: $name, members: ${profileIds.length}, '
      'workflows: ${workflowIds.length}, tasks: ${tasks.length}, '
      'activeTask: $activeTaskId)';
}

class StationsState {
  final List<Station> stations;
  final String? selectedStationId;

  const StationsState({this.stations = const [], this.selectedStationId});

  Station? get selectedStation {
    final id = selectedStationId;
    if (id == null) return null;
    for (final station in stations) {
      if (station.id == id) return station;
    }
    return null;
  }

  StationsState copyWith({
    List<Station>? stations,
    String? selectedStationId,
    bool clearSelection = false,
  }) {
    return StationsState(
      stations: stations ?? this.stations,
      selectedStationId: clearSelection
          ? null
          : (selectedStationId ?? this.selectedStationId),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StationsState &&
          runtimeType == other.runtimeType &&
          listEquals(stations, other.stations) &&
          selectedStationId == other.selectedStationId;

  @override
  int get hashCode => Object.hash(Object.hashAll(stations), selectedStationId);

  @override
  String toString() =>
      'StationsState(stations: ${stations.length}, '
      'selected: $selectedStationId)';
}
