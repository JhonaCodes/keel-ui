import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/modules/workflows/model/workflow_capability.dart';

export 'package:keel_ui/src/modules/workflows/model/workflow_capability.dart';

enum WorkflowKind { general, bug, migration, roadmap }

enum WorkflowQualityGate { analysis, focusedTests, compatibility, regression }

/// Declarative policy for an adaptive workflow. It describes the evidence and
/// capabilities a case needs, never an ordered chain of agents.
class WorkflowPolicy {
  final String resolutionRole;
  final List<String> requiredSkillNames;
  final List<String> requiredRuleNames;
  final List<String> requiredKnowledgeBaseNames;
  final List<WorkflowQualityGate> qualityGates;
  final int maxReplans;
  final int maxSubagents;
  final int maxReviewCycles;

  const WorkflowPolicy({
    this.resolutionRole = '',
    this.requiredSkillNames = const [],
    this.requiredRuleNames = const [],
    this.requiredKnowledgeBaseNames = const [],
    this.qualityGates = const [
      WorkflowQualityGate.analysis,
      WorkflowQualityGate.focusedTests,
    ],
    this.maxReplans = 2,
    this.maxSubagents = 1,
    this.maxReviewCycles = 4,
  });

  WorkflowPolicy copyWith({
    String? resolutionRole,
    List<String>? requiredSkillNames,
    List<String>? requiredRuleNames,
    List<String>? requiredKnowledgeBaseNames,
    List<WorkflowQualityGate>? qualityGates,
    int? maxReplans,
    int? maxSubagents,
    int? maxReviewCycles,
  }) => WorkflowPolicy(
    resolutionRole: resolutionRole ?? this.resolutionRole,
    requiredSkillNames: requiredSkillNames ?? this.requiredSkillNames,
    requiredRuleNames: requiredRuleNames ?? this.requiredRuleNames,
    requiredKnowledgeBaseNames:
        requiredKnowledgeBaseNames ?? this.requiredKnowledgeBaseNames,
    qualityGates: qualityGates ?? this.qualityGates,
    maxReplans: maxReplans ?? this.maxReplans,
    maxSubagents: maxSubagents ?? this.maxSubagents,
    maxReviewCycles: maxReviewCycles ?? this.maxReviewCycles,
  );

  Map<String, dynamic> toJson() => {
    'resolutionRole': resolutionRole,
    'requiredSkillNames': requiredSkillNames,
    'requiredRuleNames': requiredRuleNames,
    'requiredKnowledgeBaseNames': requiredKnowledgeBaseNames,
    'qualityGates': qualityGates.map((gate) => gate.name).toList(),
    'maxReplans': maxReplans,
    'maxSubagents': maxSubagents,
    'maxReviewCycles': maxReviewCycles,
  };

  factory WorkflowPolicy.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return WorkflowPolicy(
      resolutionRole: data['resolutionRole'] as String? ?? '',
      requiredSkillNames:
          (data['requiredSkillNames'] as List?)?.cast<String>() ?? const [],
      requiredRuleNames:
          (data['requiredRuleNames'] as List?)?.cast<String>() ?? const [],
      requiredKnowledgeBaseNames:
          (data['requiredKnowledgeBaseNames'] as List?)?.cast<String>() ??
          const [],
      qualityGates: (data['qualityGates'] as List? ?? const [])
          .map((entry) => _qualityGateFromName(entry as String?))
          .whereType<WorkflowQualityGate>()
          .toList(),
      maxReplans: (data['maxReplans'] as int? ?? 2).clamp(0, 2),
      maxSubagents: (data['maxSubagents'] as int? ?? 1).clamp(0, 1),
      maxReviewCycles: (data['maxReviewCycles'] as int? ?? 4).clamp(1, 4),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkflowPolicy &&
          runtimeType == other.runtimeType &&
          resolutionRole == other.resolutionRole &&
          listEquals(requiredSkillNames, other.requiredSkillNames) &&
          listEquals(requiredRuleNames, other.requiredRuleNames) &&
          listEquals(
            requiredKnowledgeBaseNames,
            other.requiredKnowledgeBaseNames,
          ) &&
          listEquals(qualityGates, other.qualityGates) &&
          maxReplans == other.maxReplans &&
          maxSubagents == other.maxSubagents &&
          maxReviewCycles == other.maxReviewCycles;

  @override
  int get hashCode => Object.hash(
    resolutionRole,
    Object.hashAll(requiredSkillNames),
    Object.hashAll(requiredRuleNames),
    Object.hashAll(requiredKnowledgeBaseNames),
    Object.hashAll(qualityGates),
    maxReplans,
    maxSubagents,
    maxReviewCycles,
  );
}

WorkflowQualityGate? _qualityGateFromName(String? name) {
  for (final gate in WorkflowQualityGate.values) {
    if (gate.name == name) return gate;
  }
  return null;
}

WorkflowKind _workflowKindFromName(String? name) {
  for (final kind in WorkflowKind.values) {
    if (kind.name == name) return kind;
  }
  return WorkflowKind.general;
}

/// Returns a human error message if [value] can't be used as a
/// [Workflow.name], or null if it's valid.
String? validateWorkflowName(String value) {
  if (value.isEmpty) return 'El nombre no puede estar vacío.';
  if (value.length > 60) return 'Máximo 60 caracteres.';
  return null;
}

/// A registered, reusable adaptive workflow. [whenToApply] describes its
/// trigger; [policy] describes context and quality requirements.
class Workflow {
  final String id;
  final String name;
  final String whenToApply;
  final DateTime createdAt;

  /// A workflow's intent. It drives its graph and validation gates instead of
  /// an ordered list of agents.
  final WorkflowKind kind;

  final WorkflowPolicy policy;
  final List<WorkflowCapability> capabilities;

  /// Skills que este workflow suma a TODOS sus turnos, por nombre.
  ///
  /// Distintas de las del agente: las del agente son quién es —un experto en
  /// Flutter lo es en todos lados— y estas son qué está haciendo. El mismo
  /// agente formateando la carpeta de tareas necesita saber el formato; ese
  /// mismo agente resolviendo un ticket, no.
  final List<String> skillNames;

  /// Este workflow CONSTRUYE la carpeta de tareas.
  ///
  /// Dos cosas cuelgan de acá, y las dos son de la carpeta y no del
  /// workflow en general: sus turnos reciben el lector del roadmap aunque la
  /// carpeta todavía no exista —es justo la que la está creando— y al cerrar
  /// se chequea el formato antes de sellar la sesión.
  final bool buildsRoadmap;

  const Workflow({
    required this.id,
    required this.name,
    required this.whenToApply,
    required this.createdAt,
    this.skillNames = const [],
    this.buildsRoadmap = false,
    this.kind = WorkflowKind.general,
    this.policy = const WorkflowPolicy(),
    this.capabilities = const [],
  });

  Workflow copyWith({
    String? name,
    String? whenToApply,
    List<String>? skillNames,
    bool? buildsRoadmap,
    WorkflowKind? kind,
    WorkflowPolicy? policy,
    List<WorkflowCapability>? capabilities,
  }) {
    return Workflow(
      id: id,
      name: name ?? this.name,
      whenToApply: whenToApply ?? this.whenToApply,
      skillNames: skillNames ?? this.skillNames,
      buildsRoadmap: buildsRoadmap ?? this.buildsRoadmap,
      kind: kind ?? this.kind,
      policy: policy ?? this.policy,
      capabilities: capabilities ?? this.capabilities,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'whenToApply': whenToApply,
    'skillNames': skillNames,
    'buildsRoadmap': buildsRoadmap,
    'kind': kind.name,
    'policy': policy.toJson(),
    'capabilities': capabilities.map((entry) => entry.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory Workflow.fromJson(Map<String, dynamic> json) {
    final kind = _workflowKindFromName(json['kind'] as String?);
    final policy = WorkflowPolicy.fromJson(
      (json['policy'] as Map?)?.cast<String, dynamic>(),
    );
    final storedCapabilities = (json['capabilities'] as List? ?? const [])
        .map(
          (entry) => WorkflowCapability.fromJson(
            (entry as Map).cast<String, dynamic>(),
          ),
        )
        .toList();
    return Workflow(
      id: json['id'] as String,
      name: json['name'] as String,
      whenToApply: json['whenToApply'] as String? ?? '',
      skillNames: (json['skillNames'] as List?)?.cast<String>() ?? const [],
      buildsRoadmap: json['buildsRoadmap'] as bool? ?? false,
      kind: kind,
      policy: policy,
      capabilities: storedCapabilities.isEmpty
          ? defaultWorkflowCapabilities(kind, policy.resolutionRole)
          : storedCapabilities,
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
          listEquals(skillNames, other.skillNames) &&
          buildsRoadmap == other.buildsRoadmap &&
          kind == other.kind &&
          policy == other.policy &&
          listEquals(capabilities, other.capabilities) &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    whenToApply,
    Object.hashAll(skillNames),
    buildsRoadmap,
    kind,
    policy,
    Object.hashAll(capabilities),
    createdAt,
  );

  @override
  String toString() =>
      'Workflow(id: $id, name: $name, whenToApply: $whenToApply, '
      'kind: ${kind.name}, createdAt: $createdAt)';
}

List<WorkflowCapability> defaultWorkflowCapabilities(
  WorkflowKind kind,
  String resolutionRole,
) {
  final owner = resolutionRole.trim();
  final fallback = owner.isEmpty ? '*' : owner;
  if (kind == WorkflowKind.roadmap) {
    return [
      WorkflowCapability(
        id: 'implementation',
        title: 'Construir formato de tareas',
        instruction: 'Crear o corregir el formato TASKS del proyecto.',
        role: fallback,
      ),
      WorkflowCapability(
        id: 'verification',
        title: 'Verificar formato',
        instruction: 'Validar estructura, referencias y frontmatter.',
        role: fallback,
        dependencyIds: const ['implementation'],
      ),
    ];
  }
  return [
    WorkflowCapability(
      id: 'planner',
      title: 'Planificar y delimitar',
      instruction: 'Definir alcance, riesgos y criterios de aceptación.',
      role: fallback,
      readOnly: true,
      maxAgenticTurns: 4,
    ),
    if (kind == WorkflowKind.migration)
      WorkflowCapability(
        id: 'impact',
        title: 'Diseño del punto único de entrada',
        instruction: 'Inventariar impacto end-to-end y compatibilidad.',
        role: fallback,
        dependencyIds: const ['planner'],
      ),
    WorkflowCapability(
      id: 'implementation',
      title: 'Implementar con evidencia',
      instruction: 'Aplicar la corrección mínima integrada y verificable.',
      role: fallback,
      dependencyIds: [kind == WorkflowKind.migration ? 'impact' : 'planner'],
      maxAgenticTurns: 12,
    ),
    WorkflowCapability(
      id: 'code-audit',
      title: 'Auditar código',
      instruction: 'Revisar calidad, invariantes y riesgos del cambio.',
      role: 'auditor',
      dependencyIds: const ['implementation'],
      executor: WorkflowExecutor.providerSubagent,
      parentCapabilityId: 'implementation',
      maxAgenticTurns: 3,
      readOnly: true,
      outputContract: 'audit-feedback',
      requiresIndependentOwner: true,
    ),
    WorkflowCapability(
      id: 'code-correction',
      title: 'Corregir hallazgos de código',
      instruction: 'Resolver los hallazgos válidos de la auditoría de código.',
      role: fallback,
      dependencyIds: const ['code-audit'],
      executor: WorkflowExecutor.resumeParent,
      parentCapabilityId: 'implementation',
      maxAgenticTurns: 8,
    ),
    WorkflowCapability(
      id: 'tests',
      title: 'Crear y ajustar pruebas',
      instruction: 'Crear o ajustar pruebas de la implementación.',
      role: fallback,
      dependencyIds: const ['code-correction'],
      executor: WorkflowExecutor.resumeParent,
      parentCapabilityId: 'implementation',
      maxAgenticTurns: 8,
    ),
    WorkflowCapability(
      id: 'test-audit',
      title: 'Auditar tests',
      instruction: 'Comprobar cobertura y valor contrafactual de las pruebas.',
      role: 'test-auditor',
      dependencyIds: const ['tests'],
      executor: WorkflowExecutor.providerSubagent,
      parentCapabilityId: 'implementation',
      maxAgenticTurns: 3,
      readOnly: true,
      outputContract: 'audit-feedback',
      requiresIndependentOwner: true,
    ),
    WorkflowCapability(
      id: 'test-correction',
      title: 'Corregir hallazgos de tests',
      instruction: 'Resolver los hallazgos válidos de la auditoría de pruebas.',
      role: fallback,
      dependencyIds: const ['test-audit'],
      executor: WorkflowExecutor.resumeParent,
      parentCapabilityId: 'implementation',
      maxAgenticTurns: 8,
    ),
    WorkflowCapability(
      id: 'device-e2e',
      title: 'Verificación end-to-end en dispositivo',
      instruction: 'Validar el comportamiento completo en el entorno real.',
      role: 'verifier',
      dependencyIds: const ['test-correction'],
      activation: WorkflowCapabilityActivation.optional,
      requiresIndependentOwner: true,
    ),
    WorkflowCapability(
      id: 'verification',
      title: 'Verificación de cierre',
      instruction: 'Ejecutar gates y cerrar solo con evidencia suficiente.',
      role: fallback,
      dependencyIds: const ['test-correction'],
      executor: WorkflowExecutor.resumeParent,
      parentCapabilityId: 'implementation',
      maxAgenticTurns: 6,
    ),
    WorkflowCapability(
      id: 'publish-approval',
      title: 'Aprobar publicación',
      instruction: 'Esperar aprobación explícita antes de publicar.',
      role: fallback,
      dependencyIds: const ['verification'],
      executor: WorkflowExecutor.manualApproval,
      readOnly: true,
    ),
    WorkflowCapability(
      id: 'publish',
      title: 'Publicar',
      instruction: 'Publicar únicamente después de aprobación explícita.',
      role: fallback,
      dependencyIds: const ['publish-approval'],
      executor: WorkflowExecutor.resumeParent,
      parentCapabilityId: 'implementation',
      maxAgenticTurns: 4,
    ),
  ];
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
