import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/projects/model/resolution_evidence.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_case.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_finding.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_preflight.dart';
import 'package:keel_ui/src/modules/projects/model/migration_coverage.dart';
import 'package:keel_ui/src/modules/projects/model/session_decision.dart';
import 'package:keel_ui/src/modules/projects/model/turn_outcome_report.dart';
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

  group('applyOutcome', () {
    ResolutionCase graph() {
      final started = ResolutionEngine.start(
        id: 'case-1',
        kind: WorkflowKind.bug,
        ownerRole: 'implementador',
      );
      // Todo lo anterior a la auditoría ya cerró.
      return started.copyWith(
        nodes: [
          for (final node in started.nodes)
            node.id == 'planner' || node.id == 'implementation'
                ? node.copyWith(status: WorkNodeStatus.done)
                : node,
        ],
      );
    }

    String nextId() => 'id-${DateTime.now().microsecondsSinceEpoch}';

    test('un NO-GO de la auditoría devuelve el nodo auditado a pending, '
        'deja el hallazgo asignado y re-abre la auditoría', () {
      final noGo = ResolutionEngine.applyOutcome(
        graph(),
        nodeId: 'code-audit',
        report: const TurnOutcomeReport(
          status: TurnOutcomeStatus.done,
          summary: 'unwrap en lib/a.dart:12',
          verdict: TurnVerdict.noGo,
        ),
        isAudit: true,
        parentNodeId: 'implementation',
        maxReplans: 2,
        profileId: 'auditor',
        now: DateTime(2026),
        newId: nextId,
      );

      final resolution = noGo.resolution;
      WorkNodeStatus statusOf(String id) =>
          resolution.nodes.firstWhere((node) => node.id == id).status;

      expect(statusOf('implementation'), WorkNodeStatus.pending);
      expect(statusOf('code-audit'), WorkNodeStatus.pending);
      expect(resolution.status, ResolutionCaseStatus.active);
      expect(resolution.reviewCycleCount, 1);
      expect(resolution.findings, hasLength(1));
      expect(resolution.findings.single.status, ResolutionFindingStatus.assigned);
      expect(resolution.findings.single.affectedNodeId, 'implementation');
      expect(
        resolution.findings.single.evidence.source,
        ResolutionEvidenceSource.review,
      );
      expect(ResolutionEngine.canComplete(resolution), isFalse);
      expect(noGo.decision, isNull);

      // La corrección cierra y la auditoría vuelve con GO: el hallazgo queda
      // resuelto y el caso puede cerrar cuando el resto termine.
      final fixed = ResolutionEngine.applyOutcome(
        resolution,
        nodeId: 'implementation',
        report: const TurnOutcomeReport(
          status: TurnOutcomeStatus.done,
          summary: 'unwrap reemplazado por ?',
        ),
        isAudit: false,
        maxReplans: 2,
        profileId: 'dev',
        now: DateTime(2026),
        newId: nextId,
      ).resolution;
      final go = ResolutionEngine.applyOutcome(
        fixed,
        nodeId: 'code-audit',
        report: const TurnOutcomeReport(
          status: TurnOutcomeStatus.done,
          summary: 'sin hallazgos',
          verdict: TurnVerdict.go,
        ),
        isAudit: true,
        parentNodeId: 'implementation',
        maxReplans: 2,
        profileId: 'auditor',
        now: DateTime(2026),
        newId: nextId,
      ).resolution;

      expect(
        go.findings.single.status,
        ResolutionFindingStatus.resolved,
      );
      expect(
        go.nodes.firstWhere((node) => node.id == 'code-audit').status,
        WorkNodeStatus.done,
      );
      expect(
        go.nodes.firstWhere((node) => node.id == 'code-audit').output?.verdict,
        TurnVerdict.go,
      );
    });

    test('needs_user pausa el nodo y deja una decisión pendiente', () {
      final application = ResolutionEngine.applyOutcome(
        graph(),
        nodeId: 'code-audit',
        report: const TurnOutcomeReport(
          status: TurnOutcomeStatus.needsUser,
          summary: 'no sé qué rama auditar',
          question: '¿main o develop?',
        ),
        isAudit: true,
        parentNodeId: 'implementation',
        maxReplans: 2,
        profileId: 'auditor',
        now: DateTime(2026),
        newId: nextId,
      );

      expect(
        application.resolution.nodes
            .firstWhere((node) => node.id == 'code-audit')
            .status,
        WorkNodeStatus.paused,
      );
      expect(application.resolution.status, ResolutionCaseStatus.active);
      final decision = application.decision;
      expect(decision, isNotNull);
      expect(decision!.kind, SessionDecisionKind.question);
      expect(decision.workNodeId, 'code-audit');
      expect(decision.profileId, 'auditor');
      expect(decision.detail, '¿main o develop?');
      expect(decision.status, SessionDecisionStatus.pending);
    });

    test('next activa una capacidad opcional sin tocar el resto', () {
      final application = ResolutionEngine.applyOutcome(
        graph(),
        nodeId: 'code-audit',
        report: const TurnOutcomeReport(
          status: TurnOutcomeStatus.done,
          summary: 'ok',
          verdict: TurnVerdict.go,
          next: 'device-e2e',
        ),
        isAudit: true,
        parentNodeId: 'implementation',
        maxReplans: 2,
        profileId: 'auditor',
        now: DateTime(2026),
        newId: nextId,
      );

      expect(application.activateCapabilityId, 'device-e2e');
    });

    test('blocked registra un hallazgo de contrato y reintenta el nodo', () {
      final application = ResolutionEngine.applyOutcome(
        graph(),
        nodeId: 'code-audit',
        report: const TurnOutcomeReport(
          status: TurnOutcomeStatus.blocked,
          summary: 'el repo no compila por un cambio ajeno',
        ),
        isAudit: true,
        parentNodeId: 'implementation',
        maxReplans: 2,
        profileId: 'auditor',
        now: DateTime(2026),
        newId: nextId,
      );

      final resolution = application.resolution;
      expect(resolution.findings.single.evidence.source,
          ResolutionEvidenceSource.contract);
      expect(
        resolution.nodes.firstWhere((node) => node.id == 'code-audit').status,
        WorkNodeStatus.pending,
      );
      expect(resolution.status, ResolutionCaseStatus.active);
    });
  });
}
