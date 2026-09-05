import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/projects/model/resolution_evidence.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_case.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_finding.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_preflight.dart';
import 'package:keel_ui/src/modules/projects/model/migration_coverage.dart';
import 'package:keel_ui/src/modules/projects/model/work_node.dart';
import 'package:keel_ui/src/modules/projects/service/resolution_engine.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

void main() {
  final evidence = ResolutionEvidence(
    id: 'lint-1',
    source: ResolutionEvidenceSource.linter,
    summary: 'String no pertenece a AgentProvider.',
    fingerprint: 'agent-provider-type',
    createdAt: DateTime(2026),
  );

  test('migración construye un grafo end-to-end, no una cadena de pasos', () {
    final resolution = ResolutionEngine.start(
      id: 'case-1',
      kind: WorkflowKind.migration,
      ownerRole: 'integrador',
    );

    expect(resolution.status, ResolutionCaseStatus.active);
    expect(
      resolution.nodes.map((node) => node.id),
      containsAllInOrder([
        'planner',
        'impact',
        'implementation',
        'code-audit',
        'code-correction',
        'tests',
        'test-audit',
        'test-correction',
        'verification',
      ]),
    );
    expect(
      resolution.nodes.firstWhere((node) => node.id == 'implementation').dependencyIds,
      ['impact'],
    );
    expect(
      resolution.nodes.firstWhere((node) => node.id == 'verification').dependencyIds,
      ['test-correction'],
    );
    expect(resolution.coverage, hasLength(MigrationCoverageArea.values.length));
  });

  test('migración no cierra con cobertura pendiente ni N/A sin motivo', () {
    final resolution = ResolutionEngine.start(
      id: 'case-1',
      kind: WorkflowKind.migration,
      ownerRole: 'integrador',
    );
    final rejected = ResolutionEngine.setCoverage(
      resolution,
      area: MigrationCoverageArea.ui,
      status: MigrationCoverageStatus.notApplicable,
      rationale: '',
    );

    expect(rejected.coverage, equals(resolution.coverage));
    expect(ResolutionEngine.canComplete(resolution), isFalse);
  });

  test('instancia solo capacidades requeridas con su agente concreto', () {
    final resolution = ResolutionEngine.start(
      id: 'case-capabilities',
      kind: WorkflowKind.bug,
      ownerRole: 'resolver',
      capabilities: const [
        WorkflowCapability(
          id: 'diagnose',
          title: 'Diagnosticar',
          instruction: 'Aislar la causa.',
          role: 'diagnosticador',
        ),
        WorkflowCapability(
          id: 'audit',
          title: 'Auditar',
          instruction: 'Revisar independiente.',
          role: 'auditor',
          dependencyIds: ['diagnose'],
          activation: WorkflowCapabilityActivation.optional,
        ),
      ],
      ownerProfileIds: const {'diagnose': 'profile-diagnosticador'},
    );

    expect(resolution.nodes, hasLength(1));
    expect(resolution.nodes.single.id, 'diagnose');
    expect(resolution.nodes.single.ownerRole, 'diagnosticador');
    expect(resolution.nodes.single.ownerProfileId, 'profile-diagnosticador');
    expect(resolution.nodes.single.title, 'Diagnosticar');

    final activated = ResolutionEngine.activateCapability(
      resolution,
      capability: const WorkflowCapability(
        id: 'audit',
        title: 'Auditar',
        instruction: 'Revisar independiente.',
        role: 'auditor',
        dependencyIds: ['diagnose'],
        activation: WorkflowCapabilityActivation.optional,
      ),
      ownerProfileId: 'profile-auditor',
    );
    expect(activated.nodes, hasLength(2));
    expect(activated.nodes.last.ownerProfileId, 'profile-auditor');
  });

  test('hallazgo repetido no relanza el mismo intento', () {
    final resolution = ResolutionEngine.start(
      id: 'case-1',
      kind: WorkflowKind.bug,
      ownerRole: 'responsable',
    );

    final first = ResolutionEngine.reportFinding(
      resolution,
      evidence: evidence,
      affectedNodeId: 'implementation',
      maxReplans: 2,
    );
    final repeated = ResolutionEngine.reportFinding(
      first.resolution,
      evidence: evidence,
      affectedNodeId: 'implementation',
      maxReplans: 2,
    );

    expect(first.accepted, isTrue);
    expect(first.resolution.status, ResolutionCaseStatus.replanning);
    expect(first.resolution.findings.single.affectedNodeId, 'implementation');
    expect(
      first.resolution.nodes
          .firstWhere((node) => node.id == 'implementation')
          .status,
      WorkNodeStatus.paused,
    );
    expect(repeated.accepted, isFalse);
    expect(repeated.resolution.findings, hasLength(1));
  });

  test('dos reformulaciones sin progreso bloquean el caso con evidencia', () {
    final resolution = ResolutionEngine.start(
      id: 'case-1',
      kind: WorkflowKind.bug,
      ownerRole: 'responsable',
    );
    final first = ResolutionEngine.reportFinding(
      resolution,
      evidence: evidence,
      affectedNodeId: 'implementation',
      maxReplans: 2,
    );
    final second = ResolutionEngine.reportFinding(
      first.resolution,
      evidence: ResolutionEvidence(
        id: 'test-1',
        source: ResolutionEvidenceSource.test,
        summary: 'La regresión sigue fallando.',
        fingerprint: 'agent-provider-regression',
        createdAt: DateTime(2026),
      ),
      affectedNodeId: 'verification',
      maxReplans: 2,
    );

    expect(second.resolution.status, ResolutionCaseStatus.blocked);
    expect(second.resolution.findings, hasLength(2));
  });

  test('cerrar un nodo resuelve solo sus propios hallazgos', () {
    final resolution = ResolutionEngine.start(
      id: 'case-findings',
      kind: WorkflowKind.bug,
      ownerRole: 'resolver',
    );
    final implementation = ResolutionEngine.reportFinding(
      resolution,
      evidence: evidence,
      affectedNodeId: 'implementation',
      maxReplans: 3,
    ).resolution;
    final withVerification = ResolutionEngine.reportFinding(
      implementation,
      evidence: ResolutionEvidence(
        id: 'verification-1',
        source: ResolutionEvidenceSource.test,
        summary: 'Regresión pendiente.',
        fingerprint: 'verification-regression',
        createdAt: DateTime(2026),
      ),
      affectedNodeId: 'verification',
      maxReplans: 3,
    ).resolution;

    final resolved = ResolutionEngine.resolveAssignedFindings(
      withVerification,
      affectedNodeId: 'implementation',
    );

    expect(resolved.findings[0].status, ResolutionFindingStatus.resolved);
    expect(resolved.findings[1].status, ResolutionFindingStatus.assigned);
  });

  test('persiste el contexto inyectado y los faltantes del preflight', () {
    final restored = ResolutionCase.fromJson(
      const ResolutionCase(
        id: 'blocked-preflight',
        ownerRole: 'resolver',
        status: ResolutionCaseStatus.blocked,
        preflight: ResolutionPreflight(
          performed: true,
          injectedRules: ['evidencia-primero'],
          missingSkills: ['flutter-expert'],
          missingSecrets: ['OPENROUTER_API_KEY'],
        ),
      ).toJson(),
    );

    expect(restored.preflight.injectedRules, ['evidencia-primero']);
    expect(restored.preflight.missingSkills, ['flutter-expert']);
    expect(restored.preflight.missingSecrets, ['OPENROUTER_API_KEY']);
    expect(restored.preflight.ready, isFalse);
  });

  test('interrumpir devuelve el nodo en curso a pendiente, el caso sigue', () {
    // Sin esto, un Stop a mitad de nodo dejaba el nodo en `running` para
    // siempre: `_nextReadyNode` lo salteaba y el caso "no cerraba".
    final started = ResolutionEngine.start(
      id: 'case-1',
      kind: WorkflowKind.general,
      ownerRole: 'implementador',
    );
    final first = started.nodes.first.id;
    final running = started.copyWith(
      nodes: [
        for (final node in started.nodes)
          node.id == first ? node.copyWith(status: WorkNodeStatus.running) : node,
      ],
    );

    final released = ResolutionEngine.releaseRunningNodes(running);

    expect(
      released.nodes.firstWhere((node) => node.id == first).status,
      WorkNodeStatus.pending,
    );
    expect(released.status, ResolutionCaseStatus.active);
    expect(released.nodes.where((n) => n.status == WorkNodeStatus.running), isEmpty);
  });
}
