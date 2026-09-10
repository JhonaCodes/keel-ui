import 'package:flutter/foundation.dart';

enum WorkflowCapabilityActivation { required, optional }

/// The explicit execution route for a workflow capability.
enum WorkflowExecutor {
  newSession,
  resumeParent,
  providerSubagent,
  manualApproval,
}

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
    if (capability.maxAgenticTurns < 0 ||
        capability.maxAgenticTurns > kMaxDeclarableTurns) {
      return 'La capacidad ${capability.id} debe limitar sus turnos entre 0 '
          'y $kMaxDeclarableTurns.';
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
    final parent = capability.parentCapabilityId.trim();
    if ((capability.executor == WorkflowExecutor.resumeParent ||
            capability.executor == WorkflowExecutor.providerSubagent) &&
        parent.isEmpty) {
      return 'La capacidad ${capability.id} necesita un paso padre.';
    }
    if (capability.executor == WorkflowExecutor.newSession &&
        parent.isNotEmpty) {
      return 'La capacidad ${capability.id} abre una sesión nueva y no puede tener padre.';
    }
    if (parent.isNotEmpty && !ids.contains(parent)) {
      return 'La capacidad ${capability.id} referencia un padre inexistente.';
    }
    if (parent == capability.id) {
      return 'La capacidad ${capability.id} no puede ser su propio padre.';
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

/// Turnos agénticos de un nodo que escribe cuando el workflow no declara un
/// tope. Antes `0` significaba «ilimitado», y 26 de 31 workflows guardados
/// corrían así: un nodo llegó a 577 turnos. El tope existe por eso.
///
/// Empezó en 20 y era demasiado justo: al retrofitearse sobre esos 26
/// workflows, un nodo de implementación real —cambio, test, análisis
/// estático y suite— lo agotaba de rutina. Medido contra el caso que lo
/// destapó: el nodo se cortó en el turno 21 con la suite en verde
/// (`test result: ok. 13 passed`), o sea trabajando bien, no dando vueltas.
/// Sesenta fue el intento siguiente y también se quedó corto en los nodos de
/// entrega reales. Cien deja terminar ese trabajo y sigue estando lejos de
/// los 577 que motivaron el tope; el que necesite otro número lo declara en
/// el nodo.
const int kDefaultWriteNodeTurns = 200;

/// Lo mismo para un nodo de solo lectura (planificar, auditar).
///
/// Diez alcanzaba cuando auditar era leer un diff. Ya no: un auditor tiene que
/// correr él mismo el análisis estático y los tests del área para no heredar lo
/// que reportó el implementador, y eso son varios turnos de compilación antes
/// de escribir la primera línea del veredicto.
const int kDefaultReadOnlyNodeTurns = 200;

/// El número más alto que alguien puede declarar en un nodo.
///
/// Existía como un `20` suelto repetido en tres lugares (la validación, el
/// `fromJson` y el parser del asistente), y era un techo DURO, no un
/// default: ni subiendo el campo en el formulario se podía pasar de ahí, así
/// que un nodo que necesitaba más turnos no tenía ninguna salida. Sigue
/// siendo un tope —para que un tipeo no deje un nodo dando vueltas para
/// siempre— pero con margen para el trabajo real.
const int kMaxDeclarableTurns = 200;

@immutable
class WorkflowCapability {
  final String id;
  final String title;
  final String instruction;
  final String role;
  final List<String> dependencyIds;
  final WorkflowCapabilityActivation activation;
  final WorkflowExecutor executor;
  final String parentCapabilityId;
  final int maxAgenticTurns;
  final bool readOnly;
  final String outputContract;

  /// Whether the evidence must be produced by a profile different from the
  /// profiles that produced this capability's dependencies. This is a
  /// semantic constraint, not another mandatory workflow stage.
  final bool requiresIndependentOwner;

  /// Antes de correr este nodo el motor pide la aprobación del usuario y
  /// espera. Reemplaza al nodo aparte con executor `manualApproval`: la
  /// aprobación es una decisión sobre el paso, no un paso más.
  final bool approvalRequired;

  const WorkflowCapability({
    required this.id,
    required this.title,
    required this.instruction,
    required this.role,
    this.dependencyIds = const [],
    this.activation = WorkflowCapabilityActivation.required,
    this.executor = WorkflowExecutor.newSession,
    this.parentCapabilityId = '',
    this.maxAgenticTurns = 0,
    this.readOnly = false,
    this.outputContract = '',
    this.requiresIndependentOwner = false,
    this.approvalRequired = false,
  });

  /// El tope que corre de verdad: el declarado, o el default según el nodo
  /// escriba o no. Es lo que llega a `--max-turns`; [maxAgenticTurns] queda
  /// como lo que el usuario escribió.
  int get effectiveMaxAgenticTurns => maxAgenticTurns > 0
      ? maxAgenticTurns
      : (readOnly ? kDefaultReadOnlyNodeTurns : kDefaultWriteNodeTurns);

  WorkflowCapability copyWith({
    String? title,
    String? instruction,
    String? role,
    List<String>? dependencyIds,
    WorkflowCapabilityActivation? activation,
    WorkflowExecutor? executor,
    String? parentCapabilityId,
    int? maxAgenticTurns,
    bool? readOnly,
    String? outputContract,
    bool? requiresIndependentOwner,
    bool? approvalRequired,
  }) => WorkflowCapability(
    id: id,
    title: title ?? this.title,
    instruction: instruction ?? this.instruction,
    role: role ?? this.role,
    dependencyIds: dependencyIds ?? this.dependencyIds,
    activation: activation ?? this.activation,
    executor: executor ?? this.executor,
    parentCapabilityId: parentCapabilityId ?? this.parentCapabilityId,
    maxAgenticTurns: maxAgenticTurns ?? this.maxAgenticTurns,
    readOnly: readOnly ?? this.readOnly,
    outputContract: outputContract ?? this.outputContract,
    requiresIndependentOwner:
        requiresIndependentOwner ?? this.requiresIndependentOwner,
    approvalRequired: approvalRequired ?? this.approvalRequired,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'instruction': instruction,
    'role': role,
    'dependencyIds': dependencyIds,
    'activation': activation.name,
    'executor': executor.name,
    'parentCapabilityId': parentCapabilityId,
    'maxAgenticTurns': maxAgenticTurns,
    'readOnly': readOnly,
    'outputContract': outputContract,
    'requiresIndependentOwner': requiresIndependentOwner,
    'approvalRequired': approvalRequired,
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
        executor: WorkflowExecutor.values.firstWhere(
          (value) => value.name == json['executor'],
          orElse: () => WorkflowExecutor.newSession,
        ),
        parentCapabilityId: json['parentCapabilityId'] as String? ?? '',
        maxAgenticTurns: (json['maxAgenticTurns'] as int? ?? 0)
            .clamp(0, kMaxDeclarableTurns),
        readOnly: json['readOnly'] as bool? ?? false,
        outputContract: json['outputContract'] as String? ?? '',
        requiresIndependentOwner:
            json['requiresIndependentOwner'] as bool? ?? false,
        approvalRequired: json['approvalRequired'] as bool? ?? false,
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
          executor == other.executor &&
          parentCapabilityId == other.parentCapabilityId &&
          maxAgenticTurns == other.maxAgenticTurns &&
          readOnly == other.readOnly &&
          outputContract == other.outputContract &&
          requiresIndependentOwner == other.requiresIndependentOwner &&
          approvalRequired == other.approvalRequired;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    instruction,
    role,
    Object.hashAll(dependencyIds),
    activation,
    executor,
    parentCapabilityId,
    maxAgenticTurns,
    readOnly,
    outputContract,
    requiresIndependentOwner,
    approvalRequired,
  );
}

enum WorkflowLintSeverity { error, warning, info }

/// Un hallazgo del lint de workflows. Error bloquea crear/actualizar;
/// warning e info se muestran.
class WorkflowLint {
  final WorkflowLintSeverity severity;
  final String message;

  const WorkflowLint(this.severity, this.message);

  @override
  String toString() => '${severity.name}: $message';
}

/// Cuántos nodos requeridos puede tener un workflow antes de ser un error:
/// cada nodo es un arranque que se paga; la plantilla vieja traía once.
const kMaxRequiredWorkflowNodes = 8;

/// A partir de cuántos nodos en total se avisa.
const kWorkflowNodeCountWarning = 6;

/// Lo que `validateWorkflowCapabilities` no mira: forma, no consistencia.
///
/// Existe porque Keel AI (y la gente) armaba workflows de once nodos con dos
/// auditorías del mismo contrato, una aprobación manual opcional que nunca
/// se instanciaba y auditorías sin contrato de salida que el motor no podía
/// leer. Las invariantes vivían en el prompt; acá viven en código.
List<WorkflowLint> lintWorkflowCapabilities(
  List<WorkflowCapability> capabilities,
) {
  final lints = <WorkflowLint>[];
  final required = capabilities
      .where((c) => c.activation == WorkflowCapabilityActivation.required)
      .length;
  if (required > kMaxRequiredWorkflowNodes) {
    lints.add(
      WorkflowLint(
        WorkflowLintSeverity.error,
        'Más de $kMaxRequiredWorkflowNodes nodos requeridos ($required): cada '
        'nodo es un arranque que se paga. Con el bloque de cierre y el NO-GO '
        'automático, corrección y verificación no necesitan nodo propio.',
      ),
    );
  } else if (capabilities.length > kWorkflowNodeCountWarning) {
    lints.add(
      WorkflowLint(
        WorkflowLintSeverity.warning,
        '${capabilities.length} nodos: revisá cuáles justifican su arranque.',
      ),
    );
  }

  final byId = {for (final c in capabilities) c.id: c};
  bool writes(WorkflowCapability c) =>
      !c.readOnly && c.executor != WorkflowExecutor.manualApproval;
  bool auditLike(WorkflowCapability c) {
    final role = c.role.toLowerCase();
    final roleSaysSo = role.contains('audit') ||
        role.contains('revis') ||
        role.contains('review');
    final readsAWriter = c.readOnly &&
        c.dependencyIds.any((id) => byId[id] != null && writes(byId[id]!));
    return roleSaysSo || readsAWriter;
  }

  for (final c in capabilities) {
    if (c.executor == WorkflowExecutor.manualApproval &&
        c.activation == WorkflowCapabilityActivation.optional) {
      lints.add(
        WorkflowLint(
          WorkflowLintSeverity.error,
          "'${c.id}' es una aprobación manual OPCIONAL: el motor solo "
          'instancia nodos requeridos, así que nunca dispara. Marcá '
          "approvalRequired en el paso que la necesita.",
        ),
      );
    }
    if (auditLike(c) && c.outputContract != 'audit-feedback') {
      lints.add(
        WorkflowLint(
          WorkflowLintSeverity.error,
          "'${c.id}' audita (rol o solo lectura sobre un nodo que escribe) "
          "sin outputContract 'audit-feedback': el motor no leería su "
          'veredicto ni le pasaría el informe al nodo siguiente.',
        ),
      );
    }
    if (writes(c) && c.maxAgenticTurns == 0) {
      lints.add(
        WorkflowLint(
          WorkflowLintSeverity.warning,
          "'${c.id}' escribe sin tope declarado: corre con el default de "
          '$kDefaultWriteNodeTurns turnos.',
        ),
      );
    }
  }

  for (var i = 0; i < capabilities.length; i++) {
    for (var j = i + 1; j < capabilities.length; j++) {
      final a = capabilities[i];
      final b = capabilities[j];
      if (a.role.trim().toLowerCase() != b.role.trim().toLowerCase()) continue;
      if (_jaccard(a.instruction, b.instruction) < 0.8) continue;
      lints.add(
        WorkflowLint(
          WorkflowLintSeverity.warning,
          "'${a.id}' y '${b.id}': mismo rol y contrato casi idéntico. "
          'Un solo nodo con el contrato completo cuesta la mitad.',
        ),
      );
    }
  }

  for (var i = 1; i < capabilities.length; i++) {
    final c = capabilities[i];
    if (c.dependencyIds.isEmpty &&
        c.activation == WorkflowCapabilityActivation.required) {
      lints.add(
        WorkflowLint(
          WorkflowLintSeverity.info,
          "'${c.id}' no depende de nada: corre apenas arranca el caso, en "
          'paralelo con el primero.',
        ),
      );
    }
  }
  return lints;
}

double _jaccard(String a, String b) {
  Set<String> tokens(String text) => text
      .toLowerCase()
      .split(RegExp(r'[^a-záéíóúñü0-9]+'))
      .where((token) => token.length > 2)
      .toSet();
  final left = tokens(a);
  final right = tokens(b);
  if (left.isEmpty && right.isEmpty) return 1;
  final union = {...left, ...right}.length;
  if (union == 0) return 0;
  return left.intersection(right).length / union;
}
