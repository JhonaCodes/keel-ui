import 'package:keel_ui/src/modules/projects/model/resolution_case.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_evidence.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_finding.dart';
import 'package:keel_ui/src/modules/projects/model/migration_coverage.dart';
import 'package:keel_ui/src/modules/projects/model/work_node.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

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

WorkNodeKind _kindFor(String capabilityId) => switch (capabilityId) {
  'triage' => WorkNodeKind.triage,
  'impact' => WorkNodeKind.impact,
  'implementation' => WorkNodeKind.implementation,
  'verification' => WorkNodeKind.verification,
  _ => WorkNodeKind.custom,
};

class FindingRegistration {
  final ResolutionCase resolution;
  final bool accepted;

  const FindingRegistration({required this.resolution, required this.accepted});
}
