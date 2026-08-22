import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/stations/model/member_tuning.dart';
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

/// El contexto de un PROYECTO: su directorio de trabajo, los agentes que
/// viven ahí, los workflows que deciden quién actúa y cuándo, y las reglas y
/// bases de saber que todos comparten. Las tareas entran y salen; la
/// estación se configura una vez y queda.
///
/// Su granularidad es el producto o repo (`nuimarkets`, `connect`), no la
/// etapa del trabajo: la secuencia de etapas la aporta el workflow activo.
/// Reglas y bases de saber llegan SOLO a los miembros de esta estación — es
/// la frontera que evita que un proyecto sepa cosas de otro.
class Station {
  final String id;
  final String name;
  final String purpose;
  final String workingDirectory;
  final List<String> profileIds;
  final List<String> workflowIds;
  final List<String> ruleNames;

  /// Guardarraíles que corren en esta estación, por nombre. Se suman a los
  /// del perfil de cada miembro, igual que [ruleNames].
  final List<String> hookNames;

  /// Bases de saber que ven los miembros de esta estación, por nombre. En su
  /// turno reciben el MAPA de cada una (raíz, tamaño, carpetas, portada),
  /// nunca los documentos enteros: los abren ellos cuando les hacen falta.
  final List<String> knowledgeBaseNames;

  /// Con qué motor corre cada miembro ACÁ, por id de perfil. El agente es
  /// global; el modelo con el que trabaja es una decisión de esta estación,
  /// donde se sabe qué tan cara es la tarea. Lo que no está en el mapa corre
  /// con lo que dice su perfil.
  final Map<String, MemberTuning> memberTuning;
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
    this.hookNames = const [],
    this.knowledgeBaseNames = const [],
    this.memberTuning = const {},
    this.activeWorkflowId,
    this.tasks = const [],
    this.activeTaskId,
  });

  /// [member] tal como corre en esta estación: su identidad entera, con el
  /// motor que se le fijó acá si es que se le fijó alguno.
  AgentProfile tuned(AgentProfile member) =>
      memberTuning[member.id]?.applyTo(member) ?? member;

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
    List<String>? hookNames,
    List<String>? knowledgeBaseNames,
    Map<String, MemberTuning>? memberTuning,
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
      hookNames: hookNames ?? this.hookNames,
      knowledgeBaseNames: knowledgeBaseNames ?? this.knowledgeBaseNames,
      memberTuning: memberTuning ?? this.memberTuning,
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
    'hookNames': hookNames,
    'knowledgeBaseNames': knowledgeBaseNames,
    'memberTuning': {
      for (final entry in memberTuning.entries) entry.key: entry.value.toJson(),
    },
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
      hookNames: (json['hookNames'] as List?)?.cast<String>() ?? const [],
      knowledgeBaseNames:
          (json['knowledgeBaseNames'] as List?)?.cast<String>() ?? const [],
      memberTuning: _memberTuningFromJson(json['memberTuning']),
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
          listEquals(knowledgeBaseNames, other.knowledgeBaseNames) &&
          mapEquals(memberTuning, other.memberTuning) &&
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
    Object.hashAll(knowledgeBaseNames),
    Object.hashAll([
      for (final entry in memberTuning.entries)
        Object.hash(entry.key, entry.value),
    ]),
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

/// Los ajustes de motor guardados, tolerando el registro viejo: una estación
/// escrita antes de que esto existiera simplemente no trae la clave.
Map<String, MemberTuning> _memberTuningFromJson(Object? value) {
  if (value is! Map) return const {};
  final tuning = <String, MemberTuning>{};
  for (final entry in value.entries) {
    final config = entry.value;
    if (config is! Map) continue;
    tuning[entry.key as String] = MemberTuning.fromJson(
      config.cast<String, dynamic>(),
    );
  }
  return tuning;
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
