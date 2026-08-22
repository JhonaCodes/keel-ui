import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/projects/model/member_tuning.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';

final RegExp _projectNameFormat = RegExp(r'^[a-z0-9_-]{1,24}$');

/// Returns a human error message if [value] can't be used as a [Project.name],
/// or null if it's valid. Same channel-handle shape as an agent profile name,
/// just a little longer — it reads as `#mobile-con-dev` in the UI.
String? validateProjectName(String value) {
  if (value.isEmpty) return 'El nombre no puede estar vacío.';
  if (value.length > 24) return 'Máximo 24 caracteres.';
  if (value.contains(' ')) return 'No se permiten espacios.';
  if (value != value.toLowerCase()) return 'Usa solo minúsculas.';
  if (!_projectNameFormat.hasMatch(value)) {
    return 'Solo letras minúsculas, números, "-" y "_".';
  }
  return null;
}

/// El contexto de un PROYECTO: su directorio de trabajo, los agentes que
/// viven ahí, los workflows que deciden quién actúa y cuándo, y las reglas y
/// bases de saber que todos comparten. Las sesiones entran y salen; la
/// proyecto se configura una vez y queda.
///
/// Su granularidad es el producto o repo (`nuimarkets`, `connect`), no la
/// etapa del trabajo: la secuencia de etapas la aporta el workflow activo.
/// Reglas y bases de saber llegan SOLO a los miembros de este proyecto — es
/// la frontera que evita que un proyecto sepa cosas de otro.
class Project {
  final String id;
  final String name;
  final String purpose;
  final String workingDirectory;
  final List<String> profileIds;
  final List<String> workflowIds;
  final List<String> ruleNames;

  /// Guardarraíles que corren en este proyecto, por nombre. Se suman a los
  /// del perfil de cada miembro, igual que [ruleNames].
  final List<String> hookNames;

  /// Bases de saber que ven los miembros de este proyecto, por nombre. En su
  /// turno reciben el MAPA de cada una (raíz, tamaño, carpetas, portada),
  /// nunca los documentos enteros: los abren ellos cuando les hacen falta.
  final List<String> knowledgeBaseNames;

  /// Con qué motor corre cada miembro ACÁ, por id de perfil. El agente es
  /// global; el modelo con el que trabaja es una decisión de este proyecto,
  /// donde se sabe qué tan cara es la sesión. Lo que no está en el mapa corre
  /// con lo que dice su perfil.
  final Map<String, MemberTuning> memberTuning;
  final String? activeWorkflowId;
  final List<Session> sessions;
  final String? activeSessionId;
  final DateTime createdAt;

  const Project({
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
    this.sessions = const [],
    this.activeSessionId,
  });

  /// [member] tal como corre en este proyecto: su identidad entera, con el
  /// motor que se le fijó acá si es que se le fijó alguno.
  AgentProfile tuned(AgentProfile member) =>
      memberTuning[member.id]?.applyTo(member) ?? member;

  Session? get activeSession {
    final id = activeSessionId;
    if (id == null) return null;
    for (final session in sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  Project copyWith({
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
    List<Session>? sessions,
    String? activeSessionId,
    bool clearActiveSession = false,
  }) {
    return Project(
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
      sessions: sessions ?? this.sessions,
      activeSessionId: clearActiveSession
          ? null
          : (activeSessionId ?? this.activeSessionId),
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
    'sessions': sessions.map((session) => session.toJson()).toList(),
    'activeSessionId': activeSessionId,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
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
      sessions: (json['sessions'] as List? ?? const [])
          .map((entry) => Session.fromJson(entry as Map<String, dynamic>))
          .toList(),
      activeSessionId: json['activeSessionId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Project &&
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
          listEquals(sessions, other.sessions) &&
          activeSessionId == other.activeSessionId &&
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
    Object.hashAll(sessions),
    activeSessionId,
    createdAt,
  );

  @override
  String toString() =>
      'Project(id: $id, name: $name, members: ${profileIds.length}, '
      'workflows: ${workflowIds.length}, sessions: ${sessions.length}, '
      'activeSession: $activeSessionId)';
}

/// Los ajustes de motor guardados, tolerando el registro viejo: un proyecto
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

class ProjectsState {
  final List<Project> projects;
  final String? selectedProjectId;

  const ProjectsState({this.projects = const [], this.selectedProjectId});

  Project? get selectedProject {
    final id = selectedProjectId;
    if (id == null) return null;
    for (final project in projects) {
      if (project.id == id) return project;
    }
    return null;
  }

  ProjectsState copyWith({
    List<Project>? projects,
    String? selectedProjectId,
    bool clearSelection = false,
  }) {
    return ProjectsState(
      projects: projects ?? this.projects,
      selectedProjectId: clearSelection
          ? null
          : (selectedProjectId ?? this.selectedProjectId),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectsState &&
          runtimeType == other.runtimeType &&
          listEquals(projects, other.projects) &&
          selectedProjectId == other.selectedProjectId;

  @override
  int get hashCode => Object.hash(Object.hashAll(projects), selectedProjectId);

  @override
  String toString() =>
      'ProjectsState(projects: ${projects.length}, '
      'selected: $selectedProjectId)';
}
