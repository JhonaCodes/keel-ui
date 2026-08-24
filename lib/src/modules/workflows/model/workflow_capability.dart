import 'package:flutter/foundation.dart';

enum WorkflowCapabilityActivation { required, optional }

String? validateWorkflowCapabilities(List<WorkflowCapability> capabilities) {
  if (capabilities.isEmpty) return 'El workflow necesita una capacidad.';
  final ids = <String>{};
  for (final capability in capabilities) {
    if (capability.id.trim().isEmpty || !ids.add(capability.id)) {
      return 'Cada capacidad necesita un ID estable y único.';
    }
    if (capability.title.trim().isEmpty ||
        capability.instruction.trim().isEmpty ||
        capability.role.trim().isEmpty) {
      return 'Título, instrucción y rol son obligatorios en cada capacidad.';
    }
  }
  for (final capability in capabilities) {
    if (capability.requiresIndependentOwner &&
        capability.dependencyIds.isEmpty) {
      return 'La capacidad ${capability.id} necesita al menos una dependencia '
          'para exigir un agente independiente.';
    }
    if (capability.dependencyIds.any((id) => !ids.contains(id))) {
      return 'La capacidad ${capability.id} referencia una dependencia inexistente.';
    }
  }
  final visiting = <String>{};
  final visited = <String>{};
  final byId = {
    for (final capability in capabilities) capability.id: capability,
  };
  bool hasCycle(String id) {
    if (visiting.contains(id)) return true;
    if (!visited.add(id)) return false;
    visiting.add(id);
    for (final dependency in byId[id]!.dependencyIds) {
      if (hasCycle(dependency)) return true;
    }
    visiting.remove(id);
    return false;
  }

  if (ids.any(hasCycle)) return 'Las dependencias no pueden formar un ciclo.';
  return null;
}

@immutable
class WorkflowCapability {
  final String id;
  final String title;
  final String instruction;
  final String role;
  final List<String> dependencyIds;
  final WorkflowCapabilityActivation activation;

  /// Whether the evidence must be produced by a profile different from the
  /// profiles that produced this capability's dependencies. This is a
  /// semantic constraint, not another mandatory workflow stage.
  final bool requiresIndependentOwner;

  const WorkflowCapability({
    required this.id,
    required this.title,
    required this.instruction,
    required this.role,
    this.dependencyIds = const [],
    this.activation = WorkflowCapabilityActivation.required,
    this.requiresIndependentOwner = false,
  });

  WorkflowCapability copyWith({
    String? title,
    String? instruction,
    String? role,
    List<String>? dependencyIds,
    WorkflowCapabilityActivation? activation,
    bool? requiresIndependentOwner,
  }) => WorkflowCapability(
    id: id,
    title: title ?? this.title,
    instruction: instruction ?? this.instruction,
    role: role ?? this.role,
    dependencyIds: dependencyIds ?? this.dependencyIds,
    activation: activation ?? this.activation,
    requiresIndependentOwner:
        requiresIndependentOwner ?? this.requiresIndependentOwner,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'instruction': instruction,
    'role': role,
    'dependencyIds': dependencyIds,
    'activation': activation.name,
    'requiresIndependentOwner': requiresIndependentOwner,
  };

  factory WorkflowCapability.fromJson(Map<String, dynamic> json) =>
      WorkflowCapability(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        instruction: json['instruction'] as String? ?? '',
        role: json['role'] as String? ?? '',
        dependencyIds:
            (json['dependencyIds'] as List?)?.cast<String>() ?? const [],
        activation: WorkflowCapabilityActivation.values.firstWhere(
          (value) => value.name == json['activation'],
          orElse: () => WorkflowCapabilityActivation.required,
        ),
        requiresIndependentOwner:
            json['requiresIndependentOwner'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkflowCapability &&
          id == other.id &&
          title == other.title &&
          instruction == other.instruction &&
          role == other.role &&
          listEquals(dependencyIds, other.dependencyIds) &&
          activation == other.activation &&
          requiresIndependentOwner == other.requiresIndependentOwner;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    instruction,
    role,
    Object.hashAll(dependencyIds),
    activation,
    requiresIndependentOwner,
  );
}
