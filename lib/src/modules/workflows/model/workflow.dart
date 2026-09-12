import 'package:flutter/foundation.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/modules/projects/service/turn_prompt.dart'
    show kDefaultSystemPromptMaxChars;
import 'package:keel_ui/src/modules/workflows/model/workflow_capability.dart';

export 'package:keel_ui/src/modules/projects/service/turn_prompt.dart'
    show kDefaultSystemPromptMaxChars;
export 'package:keel_ui/src/modules/workflows/model/workflow_capability.dart';

/// Techo de subagentes que un NODO puede abrir, no la corrida entera: cada
/// nodo delega por sus propios motivos y el presupuesto se lleva por
/// (turno raíz, nodo). Seis entran en el mapa sin recortar y alcanzan para
/// una verificación por perspectivas —correctitud, seguridad, reproducción—
/// en paralelo, que es el caso que justifica pasar de uno.
const int kMaxSubagentsPerNode = 6;

/// Minutos sin un solo evento del proveedor antes de cortar el turno. Diez
/// es el piso: un `flutter build` o una suite larga pueden callar varios
/// minutos sin estar colgados.
/// How many times a workflow may re-plan before it gives up.
///
/// This is the default AND the number the form seeds a new workflow with:
/// the value used to be written by hand in three places (the policy, the
/// form's fallback, and the slider ceiling), and they drifted apart until
/// raising one of them crashed the editor.
const int kDefaultMaxReplans = 10;

/// The highest [kDefaultMaxReplans] anyone can dial in from the form.
const int kMaxReplans = 20;

/// Subagents a node may fan out to by default. The hard ceiling is
/// [kMaxSubagentsPerNode].
const int kDefaultMaxSubagents = 5;

/// Review rounds a capability may go through before the workflow moves on.
const int kDefaultMaxReviewCycles = 5;

/// The highest [kDefaultMaxReviewCycles] anyone can dial in from the form.
const int kMaxReviewCycles = 10;

const int kDefaultIdleTimeoutMinutes = 0;

/// Minutos que puede durar un turno de nodo, con o sin actividad.
const int kDefaultNodeTimeoutMinutes = 0;

/// Techo de gasto reportado por sesión, en dólares. Cero es «sin techo», y es
/// el default: un caso no se corta por precio salvo que alguien declare un
/// techo a mano en el formulario del workflow. Un tope heredado sin decidirlo
/// cortaba trabajo a mitad de implementación, que es el peor momento posible.
const double kDefaultMaxSessionCostUsd = 0;

/// El techo que traía [kDefaultMaxSessionCostUsd] antes de que el default
/// pasara a «sin techo». Un workflow guardado con exactamente este valor lo
/// heredó de ese default, no de una decisión, y por eso
/// [normalizeLegacyCostCeilings] lo lleva a cero una única vez.
const double kLegacyDefaultMaxSessionCostUsd = 200;

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

  /// Plazo de inactividad de un turno, en minutos. Ver [TurnWatchdog].
  final int idleTimeoutMinutes;

  /// Plazo duro de un turno de nodo, en minutos.
  final int nodeTimeoutMinutes;

  /// Techo de gasto reportado de la sesión, en dólares. Cero: sin techo. Solo
  /// cuenta lo que el proveedor informa; codex no informa costo y por eso el
  /// techo no lo frena — el preflight lo dice.
  final double maxSessionCostUsd;

  /// Un nodo cuyo dueño ya cerró una dependencia reanuda ESA sesión del CLI
  /// en vez de abrir una nueva: no vuelve a leer el repo que ya leyó.
  final bool reuseOwnerSession;

  /// Con el contexto por encima de esta fracción, el nodo arranca fresco
  /// con el resumen del caso en vez de reanudar.
  final double compactAtContextRatio;

  /// Techo del system prompt de cada turno, en caracteres.
  final int systemPromptMaxChars;

  const WorkflowPolicy({
    this.resolutionRole = '',
    this.requiredSkillNames = const [],
    this.requiredRuleNames = const [],
    this.requiredKnowledgeBaseNames = const [],
    this.qualityGates = const [
      WorkflowQualityGate.analysis,
      WorkflowQualityGate.focusedTests,
    ],
    this.maxReplans = kDefaultMaxReplans,
    this.maxSubagents = kDefaultMaxSubagents,
    this.maxReviewCycles = kDefaultMaxReviewCycles,
    this.idleTimeoutMinutes = kDefaultIdleTimeoutMinutes,
    this.nodeTimeoutMinutes = kDefaultNodeTimeoutMinutes,
    this.maxSessionCostUsd = kDefaultMaxSessionCostUsd,
    this.reuseOwnerSession = true,
    this.compactAtContextRatio = 0.7,
    this.systemPromptMaxChars = kDefaultSystemPromptMaxChars,
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
    int? idleTimeoutMinutes,
    int? nodeTimeoutMinutes,
    double? maxSessionCostUsd,
    bool? reuseOwnerSession,
    double? compactAtContextRatio,
    int? systemPromptMaxChars,
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
    idleTimeoutMinutes: idleTimeoutMinutes ?? this.idleTimeoutMinutes,
    nodeTimeoutMinutes: nodeTimeoutMinutes ?? this.nodeTimeoutMinutes,
    maxSessionCostUsd: maxSessionCostUsd ?? this.maxSessionCostUsd,
    reuseOwnerSession: reuseOwnerSession ?? this.reuseOwnerSession,
    compactAtContextRatio: compactAtContextRatio ?? this.compactAtContextRatio,
    systemPromptMaxChars: systemPromptMaxChars ?? this.systemPromptMaxChars,
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
    'idleTimeoutMinutes': idleTimeoutMinutes,
    'nodeTimeoutMinutes': nodeTimeoutMinutes,
    'maxSessionCostUsd': maxSessionCostUsd,
    'reuseOwnerSession': reuseOwnerSession,
    'compactAtContextRatio': compactAtContextRatio,
    'systemPromptMaxChars': systemPromptMaxChars,
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
      // El techo se aplica también al LEER: si acá queda por debajo del que
      // acepta la UI, un workflow guardado con un número más alto lo pierde en
      // silencio al recargarse, y el valor que el usuario eligió no sobrevive a
      // reiniciar la app. Los tres salen de las mismas constantes que el
      // formulario y el constructor, justamente para que no puedan separarse.
      maxReplans: (data['maxReplans'] as int? ?? kDefaultMaxReplans).clamp(
        0,
        kMaxReplans,
      ),
      maxSubagents: (data['maxSubagents'] as int? ?? kDefaultMaxSubagents)
          .clamp(0, kMaxSubagentsPerNode),
      maxReviewCycles:
          (data['maxReviewCycles'] as int? ?? kDefaultMaxReviewCycles).clamp(
            1,
            kMaxReviewCycles,
          ),
      idleTimeoutMinutes:
          (data['idleTimeoutMinutes'] as int? ?? kDefaultIdleTimeoutMinutes)
              .clamp(0, 240),
      nodeTimeoutMinutes:
          (data['nodeTimeoutMinutes'] as int? ?? kDefaultNodeTimeoutMinutes)
              .clamp(0, 1440),
      maxSessionCostUsd:
          ((data['maxSessionCostUsd'] as num?)?.toDouble() ??
                  kDefaultMaxSessionCostUsd)
              .clamp(0, double.infinity),
      reuseOwnerSession: data['reuseOwnerSession'] as bool? ?? true,
      compactAtContextRatio:
          ((data['compactAtContextRatio'] as num?)?.toDouble() ?? 0.7).clamp(
            0.3,
            0.95,
          ),
      systemPromptMaxChars:
          (data['systemPromptMaxChars'] as int? ?? kDefaultSystemPromptMaxChars)
              .clamp(10000, 400000),
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
          maxReviewCycles == other.maxReviewCycles &&
          idleTimeoutMinutes == other.idleTimeoutMinutes &&
          nodeTimeoutMinutes == other.nodeTimeoutMinutes &&
          maxSessionCostUsd == other.maxSessionCostUsd &&
          reuseOwnerSession == other.reuseOwnerSession &&
          compactAtContextRatio == other.compactAtContextRatio &&
          systemPromptMaxChars == other.systemPromptMaxChars;

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
    idleTimeoutMinutes,
    nodeTimeoutMinutes,
    maxSessionCostUsd,
    reuseOwnerSession,
    compactAtContextRatio,
    systemPromptMaxChars,
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
  String resolutionRole, {
  AppLocalizations? l10n,
}) {
  final owner = resolutionRole.trim();
  final fallback = owner.isEmpty ? '*' : owner;
  if (kind == WorkflowKind.roadmap) {
    return [
      WorkflowCapability(
        id: 'implementation',
        title: l10n?.workflowTitleTaskFormat ?? 'Build the task format',
        instruction: 'Crear o corregir el formato TASKS del proyecto.',
        role: fallback,
      ),
      WorkflowCapability(
        id: 'verification',
        title: l10n?.workflowTitleVerifyFormat ?? 'Verify format',
        instruction: 'Validar estructura, referencias y frontmatter.',
        role: fallback,
        dependencyIds: const ['implementation'],
      ),
    ];
  }
  if (kind != WorkflowKind.migration) {
    // Cuatro nodos. La plantilla vieja traía once: con el bloque de cierre
    // (F44) un NO-GO devuelve el nodo auditado solo, y la aprobación es una
    // decisión sobre el paso de entrega (F44), no un nodo aparte.
    return [
      WorkflowCapability(
        id: 'plan',
        title: l10n?.workflowTitlePlanAndScope ?? 'Plan and scope',
        instruction:
            'Leer lo justo del repo y definir alcance, riesgos, criterios de '
            'aceptación observables y un plan por pasos con los archivos que '
            'se van a tocar. No escribir código.',
        role: fallback,
        readOnly: true,
      ),
      WorkflowCapability(
        id: 'implement',
        title: l10n?.workflowTitleImplement ?? 'Implement with evidence',
        instruction:
            'Implementar el plan con el cambio mínimo y su test de núcleo '
            '(rojo antes, verde después), con el análisis estático y la suite '
            'afectada corriendo. Dejar en summary qué corriste y qué dio.',
        role: fallback,
        dependencyIds: const ['plan'],
      ),
      WorkflowCapability(
        id: 'audit',
        title: l10n?.workflowTitleCodeAudit ?? 'Audit code',
        instruction:
            'Auditar el cambio contra el plan y los estándares del proyecto: '
            'correctitud, tests con oráculo real, riesgos. Cada hallazgo con '
            'archivo y línea. Cerrar con verdict GO o NO-GO.',
        role: 'auditor',
        dependencyIds: const ['implement'],
        readOnly: true,

        outputContract: 'audit-feedback',
        requiresIndependentOwner: true,
      ),
      WorkflowCapability(
        id: 'deliver',
        title: 'Deliver',
        instruction:
            'Con el GO de la auditoría: un commit, push y PR en draft con '
            'resumen y plan de pruebas. Nada más que eso.',
        role: fallback,
        dependencyIds: const ['audit'],
        executor: WorkflowExecutor.resumeParent,
        parentCapabilityId: 'implement',

        approvalRequired: true,
      ),
    ];
  }
  // Migración: conserva el inventario de impacto y la matriz de cobertura.
  // Sin nodos de corrección: el NO-GO de una auditoría devuelve el nodo
  // auditado solo. La publicación es la aprobación del cierre.
  return [
    WorkflowCapability(
      id: 'planner',
      title: l10n?.workflowTitlePlanAndScope ?? 'Plan and scope',
      instruction: 'Definir alcance, riesgos y criterios de aceptación.',
      role: fallback,
      readOnly: true,
    ),
    WorkflowCapability(
      id: 'impact',
      title:
          l10n?.workflowTitleSingleEntryPoint ??
          'Design the single entry point',
      instruction: 'Inventariar impacto end-to-end y compatibilidad.',
      role: fallback,
      dependencyIds: const ['planner'],
    ),
    WorkflowCapability(
      id: 'implementation',
      title: l10n?.workflowTitleImplement ?? 'Implement with evidence',
      instruction: 'Aplicar la corrección mínima integrada y verificable.',
      role: fallback,
      dependencyIds: const ['impact'],
    ),
    WorkflowCapability(
      id: 'code-audit',
      title: l10n?.workflowTitleCodeAudit ?? 'Audit code',
      instruction:
          'Revisar calidad, invariantes y riesgos del cambio. Cerrar con '
          'verdict GO o NO-GO.',
      role: 'auditor',
      dependencyIds: const ['implementation'],
      readOnly: true,

      outputContract: 'audit-feedback',
      requiresIndependentOwner: true,
    ),
    WorkflowCapability(
      id: 'tests',
      title: l10n?.workflowTitleTests ?? 'Create and adjust tests',
      instruction: 'Crear o ajustar pruebas de la implementación.',
      role: fallback,
      dependencyIds: const ['code-audit'],
      executor: WorkflowExecutor.resumeParent,
      parentCapabilityId: 'implementation',
    ),
    WorkflowCapability(
      id: 'test-audit',
      title: l10n?.workflowTitleTestAudit ?? 'Audit tests',
      instruction:
          'Comprobar cobertura y valor contrafactual de las pruebas. Cerrar '
          'con verdict GO o NO-GO.',
      role: 'test-auditor',
      dependencyIds: const ['tests'],
      readOnly: true,

      outputContract: 'audit-feedback',
      requiresIndependentOwner: true,
    ),
    WorkflowCapability(
      id: 'device-e2e',
      title:
          l10n?.workflowTitleDeviceE2e ?? 'End-to-end verification on device',
      instruction: 'Validar el comportamiento completo en el entorno real.',
      role: 'verifier',
      dependencyIds: const ['test-audit'],
      activation: WorkflowCapabilityActivation.optional,

      requiresIndependentOwner: true,
    ),
    WorkflowCapability(
      id: 'verification',
      title: l10n?.workflowTitleVerification ?? 'Closing verification',
      instruction:
          'Ejecutar gates, cerrar la matriz de cobertura con evidencia y, '
          'con aprobación, publicar.',
      role: fallback,
      dependencyIds: const ['test-audit'],
      executor: WorkflowExecutor.resumeParent,
      parentCapabilityId: 'implementation',

      approvalRequired: true,
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
