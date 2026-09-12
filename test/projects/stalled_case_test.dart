import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/projects/model/migration_coverage.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_case.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_evidence.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_finding.dart';
import 'package:keel_ui/src/modules/projects/model/work_node.dart';
import 'package:keel_ui/src/modules/projects/service/resolution_engine.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

void main() {
  ResolutionCase graph({WorkflowKind kind = WorkflowKind.bug}) =>
      ResolutionEngine.start(
        id: 'case-1',
        kind: kind,
        ownerRole: 'implementador',
      );

  ResolutionCase withStatuses(
    ResolutionCase resolution,
    Map<String, WorkNodeStatus> statuses,
  ) => resolution.copyWith(
    nodes: [
      for (final node in resolution.nodes)
        statuses.containsKey(node.id)
            ? node.copyWith(status: statuses[node.id])
            : node,
    ],
  );

  /// Lo que hace el loop del workflow para elegir nodo: solo mira `pending`
  /// y solo toma el que tiene sus dependencias cerradas. Replicado acá para
  /// que el escenario sea el real —«no hay nodo listo»— y no un supuesto.
  bool hasReadyNode(ResolutionCase resolution) => resolution.nodes.any(
    (node) =>
        node.status == WorkNodeStatus.pending &&
        node.dependencyIds.every(
          (id) => resolution.nodes.any(
            (candidate) =>
                candidate.id == id && candidate.status == WorkNodeStatus.done,
          ),
        ),
  );

  test(
    'un nodo abandonado en running con el resto cerrado se reabre y el caso '
    'retoma, en vez de sellarse',
    () {
      // El caso real: el trabajo estaba terminado y la sesión murió igual.
      // Un turno que se fue sin declarar su bloque —error del proveedor,
      // vigilante, huella repetida— deja el nodo en `running`; nadie lo
      // libera salvo que el usuario apriete Stop.
      final started = graph();
      final orphanId = started.nodes.last.id;
      final resolution = withStatuses(started, {
        for (final node in started.nodes)
          node.id: node.id == orphanId
              ? WorkNodeStatus.running
              : WorkNodeStatus.done,
      });

      // El escenario es el que traba el loop: ningún nodo listo para correr.
      expect(hasReadyNode(resolution), isFalse);
      expect(ResolutionEngine.canComplete(resolution), isFalse);

      final stalled = ResolutionEngine.settleStalled(resolution);

      expect(stalled.outcome, StalledCaseOutcome.reopened);
      expect(
        stalled.resolution.nodes.firstWhere((node) => node.id == orphanId).status,
        WorkNodeStatus.pending,
      );
      expect(stalled.resolution.status, ResolutionCaseStatus.active);
      // Reabierto significa retomable: el loop vuelve a tener qué correr.
      expect(hasReadyNode(stalled.resolution), isTrue);
      expect(stalled.anchorNodeId, orphanId);
    },
  );

  test('un caso con todo cerrado y nada que reparar completa', () {
    final started = graph();
    final resolution = withStatuses(started, {
      for (final node in started.nodes) node.id: WorkNodeStatus.done,
    });

    final stalled = ResolutionEngine.settleStalled(resolution);

    expect(stalled.outcome, StalledCaseOutcome.completed);
    expect(stalled.resolution.status, ResolutionCaseStatus.completed);
  });

  test('el caso que de verdad no cierra nombra el paso concreto que falta '
      'y lo deja señalado para reintentar', () {
    final started = graph();
    final blockedId = started.nodes.last.id;
    final blockedTitle = started.nodes.last.title;
    final resolution = withStatuses(started, {
      for (final node in started.nodes)
        node.id: node.id == blockedId
            ? WorkNodeStatus.blocked
            : WorkNodeStatus.done,
    });

    final stalled = ResolutionEngine.settleStalled(resolution);

    expect(stalled.outcome, StalledCaseOutcome.unresolved);
    expect(stalled.reason, contains(blockedTitle));
    // Sin el ancla, el hilo no ofrece reintentar el paso y la sesión muere.
    expect(stalled.anchorNodeId, blockedId);
  });

  test('nombra el área de cobertura y el hallazgo que quedaron abiertos', () {
    final started = graph(kind: WorkflowKind.migration);
    var resolution = withStatuses(started, {
      for (final node in started.nodes) node.id: WorkNodeStatus.done,
    });
    resolution = resolution.copyWith(
      coverage: [
        for (final entry in resolution.coverage)
          entry.area == MigrationCoverageArea.persistence
              ? entry
              : entry.copyWith(
                  status: MigrationCoverageStatus.satisfied,
                  rationale: 'cubierta',
                ),
      ],
      findings: [
        ResolutionFinding(
          id: 'finding-1',
          evidence: ResolutionEvidence(
            id: 'ev-1',
            source: ResolutionEvidenceSource.review,
            summary: 'unwrap sin manejar en lib/a.dart:12',
            fingerprint: 'unwrap-a-12',
            createdAt: DateTime(2026),
          ),
          affectedNodeId: started.nodes.first.id,
          status: ResolutionFindingStatus.assigned,
        ),
      ],
    );

    final stalled = ResolutionEngine.settleStalled(resolution);

    expect(stalled.outcome, StalledCaseOutcome.unresolved);
    expect(stalled.reason, contains(MigrationCoverageArea.persistence.name));
    expect(stalled.reason, contains('unwrap sin manejar en lib/a.dart:12'));
  });
}
