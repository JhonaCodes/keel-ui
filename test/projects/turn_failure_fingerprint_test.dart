import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/projects/model/resolution_case.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_evidence.dart';
import 'package:keel_ui/src/modules/projects/model/work_node.dart';
import 'package:keel_ui/src/modules/projects/service/resolution_engine.dart';

ResolutionEvidence _mute(String nodeId, String failureMessage) =>
    ResolutionEvidence(
      id: 'ev-$nodeId-${failureMessage.hashCode}',
      source: ResolutionEvidenceSource.compiler,
      summary: failureMessage,
      fingerprint: ResolutionEngine.turnFailureFingerprint(
        nodeId: nodeId,
        answer: '',
        failureMessage: failureMessage,
      ),
      createdAt: DateTime(2026),
    );

void main() {
  group('la huella de un turno mudo', () {
    test('dos causas distintas NO son la misma evidencia', () {
      final ceiling = ResolutionEngine.turnFailureFingerprint(
        nodeId: 'implementar',
        answer: '',
        failureMessage: 'claude terminó con código 1',
      );
      final deadSession = ResolutionEngine.turnFailureFingerprint(
        nodeId: 'implementar',
        answer: '',
        failureMessage: 'No conversation found with session ID abc',
      );

      // Con la huella armada solo con la respuesta, las dos eran
      // 'implementar:' y la segunda falla bloqueaba el caso.
      expect(ceiling, isNot(deadSession));
    });

    test('la misma causa sigue colapsando en una sola evidencia', () {
      expect(
        ResolutionEngine.turnFailureFingerprint(
          nodeId: 'implementar',
          answer: '',
          failureMessage: 'claude terminó con código 1',
        ),
        ResolutionEngine.turnFailureFingerprint(
          nodeId: 'implementar',
          answer: '',
          failureMessage: 'claude terminó con código 1',
        ),
      );
    });

    test('lo que dijo el agente manda sobre el mensaje de falla', () {
      expect(
        ResolutionEngine.turnFailureCause('  no pude compilar  ', 'código 1'),
        'no pude compilar',
      );
      expect(
        ResolutionEngine.turnFailureCause('   ', '  código 1  '),
        'código 1',
      );
    });
  });

  group('el contador de bloqueo', () {
    ResolutionCase caseWith(List<String> nodeIds) => ResolutionCase(
      id: 'case-1',
      ownerRole: 'implementador',
      status: ResolutionCaseStatus.active,
      nodes: [
        for (final id in nodeIds)
          WorkNode(
            id: id,
            kind: WorkNodeKind.implementation,
            ownerRole: 'implementador',
            title: id,
          ),
      ],
    );

    test('la primera falla de un nodo no bloquea por la falla de otro', () {
      var resolution = caseWith(['contrato', 'implementar']);

      final first = ResolutionEngine.reportFinding(
        resolution,
        evidence: _mute('contrato', 'claude terminó con código 1'),
        affectedNodeId: 'contrato',
        maxReplans: 2,
      );
      resolution = first.resolution;
      expect(first.accepted, isTrue);
      expect(resolution.status, isNot(ResolutionCaseStatus.blocked));

      // Con el contador del caso, ESTA —la primera falla de `implementar`—
      // bloqueaba el caso entero: los replans se los había llevado otro nodo.
      final second = ResolutionEngine.reportFinding(
        resolution,
        evidence: _mute('implementar', 'No se encontró la sesión padre.'),
        affectedNodeId: 'implementar',
        maxReplans: 2,
      );

      expect(second.accepted, isTrue);
      expect(second.resolution.status, isNot(ResolutionCaseStatus.blocked));
      expect(
        second.resolution.nodes
            .firstWhere((node) => node.id == 'implementar')
            .status,
        WorkNodeStatus.paused,
      );
    });

    test('el segundo fallo DEL MISMO nodo sí agota sus replans', () {
      var resolution = caseWith(['implementar']);

      resolution = ResolutionEngine.reportFinding(
        resolution,
        evidence: _mute('implementar', 'claude terminó con código 1'),
        affectedNodeId: 'implementar',
        maxReplans: 2,
      ).resolution;

      final second = ResolutionEngine.reportFinding(
        resolution,
        evidence: _mute('implementar', 'No conversation found'),
        affectedNodeId: 'implementar',
        maxReplans: 2,
      );

      expect(second.resolution.status, ResolutionCaseStatus.blocked);
      expect(second.resolution.nodes.single.status, WorkNodeStatus.blocked);
    });
  });
}
