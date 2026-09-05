import 'package:keel_ui/src/modules/projects/model/resolution_case.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_evidence.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_finding.dart';
import 'package:keel_ui/src/modules/projects/model/migration_coverage.dart';
import 'package:keel_ui/src/modules/projects/model/session_decision.dart';
import 'package:keel_ui/src/modules/projects/model/turn_outcome_report.dart';
import 'package:keel_ui/src/modules/projects/model/work_node.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/shared/shared.dart';

/// Pure state transitions for the adaptive execution graph. Keeping this out
/// of the ViewModel makes retries and completion deterministic and testable.
class ResolutionEngine {
  const ResolutionEngine._();

  static ResolutionCase start({
    required String id,
    required WorkflowKind kind,
    required String ownerRole,
    List<WorkflowCapability> capabilities = const [],
    Map<String, String> ownerProfileIds = const {},
  }) {
    final templates = capabilities.isEmpty
        ? defaultWorkflowCapabilities(kind, ownerRole)
        : capabilities;
    final activeIds = {
      for (final capability in templates)
        if (capability.activation == WorkflowCapabilityActivation.required)
          capability.id,
    };
    final nodes = [
      for (final capability in templates)
        if (activeIds.contains(capability.id))
          WorkNode(
            id: capability.id,
            kind: _kindFor(capability.id),
            ownerRole: capability.role,
            ownerProfileId: ownerProfileIds[capability.id] ?? '',
            title: capability.title,
            instruction: capability.instruction,
            dependencyIds: capability.dependencyIds
                .where(activeIds.contains)
                .toList(),
          ),
    ];
    return ResolutionCase(
      id: id,
      ownerRole: ownerRole,
      status: ResolutionCaseStatus.active,
      nodes: nodes,
      coverage: kind == WorkflowKind.migration
          ? [
              for (final area in MigrationCoverageArea.values)
                MigrationCoverageItem(area: area),
            ]
          : const [],
    );
  }

  static ResolutionCase activateCapability(
    ResolutionCase resolution, {
    required WorkflowCapability capability,
    required String ownerProfileId,
  }) {
    if (resolution.nodes.any((node) => node.id == capability.id)) {
      return resolution;
    }
    return resolution.copyWith(
      nodes: [
        ...resolution.nodes,
        WorkNode(
          id: capability.id,
          kind: _kindFor(capability.id),
          ownerRole: capability.role,
          ownerProfileId: ownerProfileId,
          title: capability.title,
          instruction: capability.instruction,
          dependencyIds: capability.dependencyIds,
        ),
      ],
    );
  }

  /// Devuelve a `pending` todo nodo que quedó `running`.
  ///
  /// Un Stop —o una interrupción con mensaje— corta el turno a mitad de nodo.
  /// Sin esto el nodo quedaba `running` para siempre: `_nextReadyNode` solo
  /// mira `pending`, así que al retomar no había nodo listo y el caso «no
  /// cerraba». El caso vuelve a `active` para que se lo pueda retomar.
  static ResolutionCase releaseRunningNodes(ResolutionCase resolution) {
    final released = [
      for (final node in resolution.nodes)
        node.status == WorkNodeStatus.running
            ? node.copyWith(status: WorkNodeStatus.pending)
            : node,
    ];
    return resolution.copyWith(
      nodes: released,
      status: resolution.status == ResolutionCaseStatus.blocked
          ? resolution.status
          : ResolutionCaseStatus.active,
    );
  }

  /// Aplica el bloque ```keel-outcome de un nodo al grafo.
  ///
  /// Es la única transición que lee lo que el agente DECLARÓ, no lo que el
  /// motor adivinó del texto. Devuelve el grafo nuevo y, si corresponde, la
  /// decisión que hay que pedirle al usuario o la capacidad opcional que el
  /// agente pidió activar. Puro: el ViewModel persiste y corre.
  static OutcomeApplication applyOutcome(
    ResolutionCase resolution, {
    required String nodeId,
    required TurnOutcomeReport report,
    required bool isAudit,
    required int maxReplans,
    required String profileId,
    required DateTime now,
    required String Function() newId,
    String parentNodeId = '',
  }) {
    final node = resolution.nodes.where((entry) => entry.id == nodeId).first;
    final stamped = _replaceNodeWith(
      resolution,
      nodeId,
      node.copyWith(output: report, attempts: node.attempts + 1),
    );
    final activate = report.next.trim().isEmpty ? null : report.next.trim();

    switch (report.status) {
      case TurnOutcomeStatus.done:
        if (isAudit && report.verdict == TurnVerdict.noGo) {
          return OutcomeApplication(
            resolution: _applyNoGo(
              stamped,
              auditNodeId: nodeId,
              affectedNodeId: parentNodeId.isNotEmpty
                  ? parentNodeId
                  : (node.dependencyIds.firstOrNull ?? nodeId),
              summary: report.summary,
              maxReplans: maxReplans,
              now: now,
              newId: newId,
            ),
            activateCapabilityId: activate,
          );
        }
        return OutcomeApplication(
          resolution: resolveAssignedFindings(
            _replaceNodeStatus(stamped, nodeId, WorkNodeStatus.done),
            affectedNodeId: nodeId,
          ),
          activateCapabilityId: activate,
        );

      case TurnOutcomeStatus.needsUser:
      case TurnOutcomeStatus.needsPermission:
        final isPermission = report.status == TurnOutcomeStatus.needsPermission;
        return OutcomeApplication(
          resolution: _replaceNodeStatus(stamped, nodeId, WorkNodeStatus.paused),
          decision: SessionDecision(
            id: newId(),
            kind: isPermission
                ? SessionDecisionKind.permission
                : SessionDecisionKind.question,
            profileId: profileId,
            workNodeId: nodeId,
            title: isPermission
                ? 'Le falta un permiso para seguir'
                : 'Necesita una decisión tuya',
            detail: report.question.trim().isNotEmpty
                ? report.question.trim()
                : report.summary.trim(),
            createdAt: now,
          ),
          activateCapabilityId: activate,
        );

      case TurnOutcomeStatus.blocked:
      case TurnOutcomeStatus.failed:
        final registration = reportFinding(
          stamped,
          evidence: ResolutionEvidence(
            id: newId(),
            source: ResolutionEvidenceSource.contract,
            summary: report.summary.trim().isEmpty
                ? 'El nodo declaró ${report.status.name} sin detalle.'
                : report.summary.trim(),
            fingerprint: '$nodeId:${normalizeForMatch(report.summary)}',
            createdAt: now,
          ),
          affectedNodeId: nodeId,
          maxReplans: maxReplans,
        );
        var next = registration.resolution;
        if (!registration.accepted) {
          next = _replaceNodeStatus(
            next.copyWith(status: ResolutionCaseStatus.blocked),
            nodeId,
            WorkNodeStatus.blocked,
          );
        } else if (next.status != ResolutionCaseStatus.blocked) {
          next = _replaceNodeStatus(
            next.copyWith(status: ResolutionCaseStatus.active),
            nodeId,
            WorkNodeStatus.pending,
          );
        }
        return OutcomeApplication(
          resolution: next,
          activateCapabilityId: activate,
        );
    }
  }

  /// Un NO-GO: hallazgo de revisión sobre el nodo auditado, que vuelve a
  /// `pending`; la auditoría también vuelve a `pending` para re-correr
  /// después de la corrección. Un NO-GO repetido con la misma huella no
  /// reintenta: el caso se bloquea con la evidencia.
  static ResolutionCase _applyNoGo(
    ResolutionCase resolution, {
    required String auditNodeId,
    required String affectedNodeId,
    required String summary,
    required int maxReplans,
    required DateTime now,
    required String Function() newId,
  }) {
    final registration = reportFinding(
      resolution,
      evidence: ResolutionEvidence(
        id: newId(),
        source: ResolutionEvidenceSource.review,
        summary: summary.trim().isEmpty ? 'NO-GO sin detalle.' : summary.trim(),
        fingerprint: '$auditNodeId:${normalizeForMatch(summary)}',
        createdAt: now,
      ),
      affectedNodeId: affectedNodeId,
      maxReplans: maxReplans,
    );
    var next = registration.resolution.copyWith(
      reviewCycleCount: resolution.reviewCycleCount + 1,
    );
    if (!registration.accepted || next.status == ResolutionCaseStatus.blocked) {
      return _replaceNodeStatus(
        next.copyWith(status: ResolutionCaseStatus.blocked),
        auditNodeId,
        WorkNodeStatus.blocked,
      );
    }
    next = _replaceNodeStatus(
      next.copyWith(status: ResolutionCaseStatus.active),
      affectedNodeId,
      WorkNodeStatus.pending,
    );
    return _replaceNodeStatus(next, auditNodeId, WorkNodeStatus.pending);
  }

  static ResolutionCase _replaceNodeStatus(
    ResolutionCase resolution,
    String nodeId,
    WorkNodeStatus status,
  ) => resolution.copyWith(
    nodes: [
      for (final node in resolution.nodes)
        node.id == nodeId ? node.copyWith(status: status) : node,
    ],
  );

  static ResolutionCase _replaceNodeWith(
    ResolutionCase resolution,
    String nodeId,
    WorkNode replacement,
  ) => resolution.copyWith(
    nodes: [
      for (final node in resolution.nodes)
        node.id == nodeId ? replacement : node,
    ],
  );

  /// Reintenta un nodo a mano: vuelve a `pending` y el caso a `active`.
  /// Los intentos no se tocan (los cuenta el turno); los hallazgos quedan.
  static ResolutionCase retryNode(ResolutionCase resolution, String nodeId) {
    if (resolution.status == ResolutionCaseStatus.completed) return resolution;
    return _replaceNodeStatus(
      resolution.copyWith(status: ResolutionCaseStatus.active),
      nodeId,
      WorkNodeStatus.pending,
    );
  }

  static bool canComplete(ResolutionCase resolution) {
    final nodesDone = resolution.nodes.every(
      (node) => node.status == WorkNodeStatus.done,
    );
    final coverageDone = resolution.coverage.every(
      (entry) => entry.status != MigrationCoverageStatus.pending,
    );
    return nodesDone &&
        coverageDone &&
        resolution.findings.every(
          (finding) => finding.status == ResolutionFindingStatus.resolved,
        );
  }

  static ResolutionCase resolveAssignedFindings(
    ResolutionCase resolution, {
    required String affectedNodeId,
  }) {
    return resolution.copyWith(
      findings: [
        for (final finding in resolution.findings)
          finding.affectedNodeId == affectedNodeId &&
                  finding.status == ResolutionFindingStatus.assigned
              ? finding.copyWith(status: ResolutionFindingStatus.resolved)
              : finding,
      ],
    );
  }

  static ResolutionCase setCoverage(
    ResolutionCase resolution, {
    required MigrationCoverageArea area,
    required MigrationCoverageStatus status,
    required String rationale,
  }) {
    if (status == MigrationCoverageStatus.notApplicable &&
        rationale.trim().isEmpty) {
      return resolution;
    }
    return resolution.copyWith(
      coverage: [
        for (final entry in resolution.coverage)
          entry.area == area
              ? entry.copyWith(status: status, rationale: rationale.trim())
              : entry,
      ],
    );
  }

  static FindingRegistration reportFinding(
    ResolutionCase resolution, {
    required ResolutionEvidence evidence,
    required String affectedNodeId,
    required int maxReplans,
  }) {
    final duplicate = resolution.findings.any(
      (finding) => finding.evidence.fingerprint == evidence.fingerprint,
    );
    if (duplicate) {
      return FindingRegistration(resolution: resolution, accepted: false);
    }

    final replans = resolution.replanCount + 1;
    final exhausted = replans >= maxReplans;
    final findings = [
      ...resolution.findings,
      ResolutionFinding(
        id: evidence.id,
        evidence: evidence,
        affectedNodeId: affectedNodeId,
        ownerRole: resolution.ownerRole,
        status: exhausted
            ? ResolutionFindingStatus.blocked
            : ResolutionFindingStatus.assigned,
        replanCount: replans,
      ),
    ];
    final nodes = resolution.nodes
        .map(
          (node) => node.id == affectedNodeId
              ? node.copyWith(
                  status: exhausted
                      ? WorkNodeStatus.blocked
                      : WorkNodeStatus.paused,
                )
              : node,
        )
        .toList();
    return FindingRegistration(
      accepted: true,
      resolution: resolution.copyWith(
        status: exhausted
            ? ResolutionCaseStatus.blocked
            : ResolutionCaseStatus.replanning,
        replanCount: replans,
        nodes: nodes,
        findings: findings,
      ),
    );
  }
}

/// Cómo se llamaba antes cada capacidad que se renombró.
///
/// Un caso guardado en disco tiene sus nodos con el id de ENTONCES: el nodo
/// no se vuelve a crear, así que el renombre de la plantilla no lo alcanza.
/// Quien busca un nodo por el id nuevo tiene que poder encontrar al viejo.
const kLegacyCapabilityIds = <String, String>{'planner': 'triage'};

WorkNodeKind _kindFor(String capabilityId) => switch (capabilityId) {
  'planner' || 'plan' => WorkNodeKind.triage,
  'triage' => WorkNodeKind.triage,
  'impact' => WorkNodeKind.impact,
  'implementation' || 'implement' => WorkNodeKind.implementation,
  'verification' => WorkNodeKind.verification,
  _ => WorkNodeKind.custom,
};

/// Lo que sale de [ResolutionEngine.applyOutcome].
class OutcomeApplication {
  final ResolutionCase resolution;
  final SessionDecision? decision;
  final String? activateCapabilityId;

  const OutcomeApplication({
    required this.resolution,
    this.decision,
    this.activateCapabilityId,
  });
}

class FindingRegistration {
  final ResolutionCase resolution;
  final bool accepted;

  const FindingRegistration({required this.resolution, required this.accepted});
}
