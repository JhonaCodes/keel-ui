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
/// el proyecto se configura una vez y queda.
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
  /// Si este proyecto es tuyo para decidir.
  ///
  /// En falso es de SOLO LECTURA: se puede consultar desde otro proyecto y
  /// puede abrir requerimientos hacia afuera, pero no toma los que le llegan
  /// ni corre sesiones que escriban en el repo. No es una traba de
  /// conveniencia: es la diferencia entre un repo que mantenés y uno que
  /// mirás, y hasta ahora la app no tenía dónde anotarla.
  final bool maintained;

  final Map<String, MemberTuning> memberTuning;

  /// Tools que concediste «para este agente en este proyecto» desde el gate.
  final Map<String, List<String>> grantedToolsByProfileId;
  final Map<String, Map<String, String>> workflowNodeAssignments;
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
    this.maintained = true,
    this.memberTuning = const {},
    this.grantedToolsByProfileId = const {},
    this.workflowNodeAssignments = const {},
    this.activeWorkflowId,
    this.sessions = const [],
    this.activeSessionId,
  });

  /// [member] tal como corre en este proyecto: su identidad entera, con el
  /// motor que se le fijó acá si es que se le fijó alguno.
  AgentProfile tuned(AgentProfile member) =>
      memberTuning[member.id]?.applyTo(member) ?? member;

  String? assignedProfileId(String workflowId, String nodeId) =>
      workflowNodeAssignments[workflowId]?[nodeId];

  /// Whether any persisted project configuration or session still names the
  /// workflow. A catalog deletion uses this to report and clean every
  /// affected project instead of leaving references that can never resolve.
  bool referencesWorkflow(String workflowId) =>
      workflowIds.contains(workflowId) ||
      activeWorkflowId == workflowId ||
      workflowNodeAssignments.containsKey(workflowId) ||
      sessions.any((session) => session.workflowId == workflowId);

  /// Every workflow ID stored anywhere inside the project aggregate.
  Set<String> get referencedWorkflowIds => {
    ...workflowIds,
    ...workflowNodeAssignments.keys,
    ?activeWorkflowId,
    for (final session in sessions)
      if (session.workflowId.isNotEmpty) session.workflowId,
  };

  /// Removes one workflow from every place where this project can reference
  /// it. Historical session content and its materialized resolution graph are
  /// preserved; only the catalog reference that no longer resolves is cleared.
  Project withoutWorkflow(String workflowId) {
    final remainingWorkflowIds = workflowIds
        .where((id) => id != workflowId)
        .toList();
    final nextActiveWorkflowId = activeWorkflowId == workflowId
        ? (remainingWorkflowIds.isEmpty ? null : remainingWorkflowIds.first)
        : activeWorkflowId;
    final assignments = {
      for (final entry in workflowNodeAssignments.entries)
        if (entry.key != workflowId)
          entry.key: Map<String, String>.from(entry.value),
    };

    return copyWith(
      workflowIds: remainingWorkflowIds,
      workflowNodeAssignments: assignments,
      activeWorkflowId: nextActiveWorkflowId,
      clearActiveWorkflow: nextActiveWorkflowId == null,
      sessions: [
        for (final session in sessions)
          if (session.workflowId == workflowId)
            session.copyWith(workflowId: '')
          else
            session,
      ],
    );
  }

  /// Repairs references left by workflows deleted by an older app version.
  Project retainingWorkflows(Set<String> existingWorkflowIds) {
    var repaired = this;
    for (final workflowId in referencedWorkflowIds) {
      if (!existingWorkflowIds.contains(workflowId)) {
        repaired = repaired.withoutWorkflow(workflowId);
      }
    }
    return repaired;
  }

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
    bool? maintained,
    Map<String, MemberTuning>? memberTuning,
    Map<String, List<String>>? grantedToolsByProfileId,
    Map<String, Map<String, String>>? workflowNodeAssignments,
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
      maintained: maintained ?? this.maintained,
      memberTuning: memberTuning ?? this.memberTuning,
      grantedToolsByProfileId:
          grantedToolsByProfileId ?? this.grantedToolsByProfileId,
      workflowNodeAssignments:
          workflowNodeAssignments ?? this.workflowNodeAssignments,
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
    'maintained': maintained,
    'memberTuning': {
      for (final entry in memberTuning.entries) entry.key: entry.value.toJson(),
    },
    'grantedToolsByProfileId': grantedToolsByProfileId,
    'workflowNodeAssignments': workflowNodeAssignments,
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
      maintained: json['maintained'] as bool? ?? true,
      memberTuning: _memberTuningFromJson(json['memberTuning']),
      grantedToolsByProfileId: {
        for (final entry
            in ((json['grantedToolsByProfileId'] as Map?) ?? const {}).entries)
          entry.key.toString(): (entry.value as List?)?.cast<String>() ??
              const <String>[],
      },
      workflowNodeAssignments: _workflowNodeAssignmentsFromJson(
        json['workflowNodeAssignments'],
      ),
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
          listEquals(hookNames, other.hookNames) &&
          listEquals(knowledgeBaseNames, other.knowledgeBaseNames) &&
          maintained == other.maintained &&
          mapEquals(memberTuning, other.memberTuning) &&
          _nestedMapEquals(
            workflowNodeAssignments,
            other.workflowNodeAssignments,
          ) &&
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
    Object.hashAll(hookNames),
    Object.hashAll(knowledgeBaseNames),
    maintained,
    Object.hashAll([
      for (final entry in memberTuning.entries)
        Object.hash(entry.key, entry.value),
    ]),
    Object.hashAll([
      for (final workflow in workflowNodeAssignments.entries)
        Object.hash(
          workflow.key,
          Object.hashAll([
            for (final assignment in workflow.value.entries)
              Object.hash(assignment.key, assignment.value),
          ]),
        ),
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

Map<String, Map<String, String>> _workflowNodeAssignmentsFromJson(
  Object? value,
) {
  if (value is! Map) return const {};
  return {
    for (final workflow in value.entries)
      if (workflow.key is String && workflow.value is Map)
        workflow.key as String: {
          for (final assignment in (workflow.value as Map).entries)
            if (assignment.key is String && assignment.value is String)
              assignment.key as String: assignment.value as String,
        },
  };
}

bool _nestedMapEquals(
  Map<String, Map<String, String>> left,
  Map<String, Map<String, String>> right,
) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (!mapEquals(entry.value, right[entry.key])) return false;
  }
  return true;
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
