import 'package:flutter/foundation.dart';

/// Returns a human error message if [value] can't be used as a
/// [Workflow.name], or null if it's valid.
String? validateWorkflowName(String value) {
  if (value.isEmpty) return 'El nombre no puede estar vacío.';
  if (value.length > 60) return 'Máximo 60 caracteres.';
  return null;
}

/// One step of a [Workflow]. [role] names a role to fill (compared against
/// an [AgentProfile]'s role by whoever runs the workflow) — not a specific
/// agent — so the same workflow can be reused across different stations.
class WorkflowStep {
  final String id;
  final String title;
  final String role;
  final String instruction;

  const WorkflowStep({
    required this.id,
    required this.title,
    required this.role,
    required this.instruction,
  });

  WorkflowStep copyWith({String? title, String? role, String? instruction}) {
    return WorkflowStep(
      id: id,
      title: title ?? this.title,
      role: role ?? this.role,
      instruction: instruction ?? this.instruction,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'role': role,
    'instruction': instruction,
  };

  factory WorkflowStep.fromJson(Map<String, dynamic> json) {
    return WorkflowStep(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      role: json['role'] as String? ?? '',
      instruction: json['instruction'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkflowStep &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          role == other.role &&
          instruction == other.instruction;

  @override
  int get hashCode => Object.hash(id, title, role, instruction);

  @override
  String toString() =>
      'WorkflowStep(id: $id, title: $title, role: $role, '
      'instruction: ${instruction.length} chars)';
}

/// A registered, reusable sequence of steps. [whenToApply] describes the
/// trigger/condition in free text (read by whoever decides to run it).
class Workflow {
  final String id;
  final String name;
  final String whenToApply;
  final List<WorkflowStep> steps;
  final DateTime createdAt;

  const Workflow({
    required this.id,
    required this.name,
    required this.whenToApply,
    required this.createdAt,
    this.steps = const [],
  });

  Workflow copyWith({
    String? name,
    String? whenToApply,
    List<WorkflowStep>? steps,
  }) {
    return Workflow(
      id: id,
      name: name ?? this.name,
      whenToApply: whenToApply ?? this.whenToApply,
      steps: steps ?? this.steps,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'whenToApply': whenToApply,
    'steps': steps.map((step) => step.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory Workflow.fromJson(Map<String, dynamic> json) {
    return Workflow(
      id: json['id'] as String,
      name: json['name'] as String,
      whenToApply: json['whenToApply'] as String? ?? '',
      steps: (json['steps'] as List? ?? const [])
          .map((entry) => WorkflowStep.fromJson(entry as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Workflow &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          whenToApply == other.whenToApply &&
          listEquals(steps, other.steps) &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      Object.hash(id, name, whenToApply, Object.hashAll(steps), createdAt);

  @override
  String toString() =>
      'Workflow(id: $id, name: $name, whenToApply: $whenToApply, '
      'steps: ${steps.length}, createdAt: $createdAt)';
}

class WorkflowsState {
  final List<Workflow> workflows;

  const WorkflowsState({this.workflows = const []});

  WorkflowsState copyWith({List<Workflow>? workflows}) {
    return WorkflowsState(workflows: workflows ?? this.workflows);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkflowsState &&
          runtimeType == other.runtimeType &&
          listEquals(workflows, other.workflows);

  @override
  int get hashCode => Object.hashAll(workflows);

  @override
  String toString() => 'WorkflowsState(workflows: ${workflows.length})';
}
