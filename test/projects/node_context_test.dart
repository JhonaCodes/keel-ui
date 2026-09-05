import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/projects/model/resolution_case.dart';
import 'package:keel_ui/src/modules/projects/model/turn_outcome_report.dart';
import 'package:keel_ui/src/modules/projects/model/work_node.dart';
import 'package:keel_ui/src/modules/projects/service/node_context.dart';

void main() {
  const implementation = WorkNode(
    id: 'implementation',
    kind: WorkNodeKind.implementation,
    ownerRole: 'implementador',
    ownerProfileId: 'dev',
    title: 'Implementar',
    status: WorkNodeStatus.done,
    output: TurnOutcomeReport(
      status: TurnOutcomeStatus.done,
      summary: 'MARCADOR-SALIDA: agregué el parser y su test.',
      files: ['lib/a.dart', 'test/a_test.dart'],
      artifacts: 'flutter test test/a_test.dart',
    ),
  );
  const audit = WorkNode(
    id: 'code-audit',
    kind: WorkNodeKind.verification,
    ownerRole: 'auditor',
    ownerProfileId: 'auditor',
    title: 'Auditar',
    dependencyIds: ['implementation'],
  );
  const deliver = WorkNode(
    id: 'deliver',
    kind: WorkNodeKind.custom,
    ownerRole: 'implementador',
    ownerProfileId: 'dev',
    title: 'Entregar',
    dependencyIds: ['implementation', 'code-audit'],
  );
  final resolution = ResolutionCase(
    id: 'case',
    ownerRole: 'implementador',
    status: ResolutionCaseStatus.active,
    nodes: const [implementation, audit, deliver],
  );

  group('dependency outputs', () {
    test('rinde lo que dejó cada dependencia cerrada, con archivos y '
        'artefactos, y omite las que no cerraron', () {
      final text = renderDependencyOutputs(
        dependencyOutputs(resolution, deliver),
      );

      expect(text, contains('Implementar'));
      expect(text, contains('MARCADOR-SALIDA'));
      expect(text, contains('lib/a.dart'));
      expect(text, contains('flutter test test/a_test.dart'));
      expect(text, isNot(contains('Auditar')));
    });

    test('recorta cada salida al tope, no la suma entera', () {
      final long = implementation.copyWith(
        output: TurnOutcomeReport(
          status: TurnOutcomeStatus.done,
          summary: 'x' * 5000,
        ),
      );
      final text = renderDependencyOutputs([(node: long, report: long.output!)]);

      expect(text.length, lessThan(kDependencyOutputMaxChars + 200));
    });
  });

  group('sessionDigest', () {
    test('resume el caso por nodo, con estado y salida, sin cuerpos del hilo',
        () {
      final digest = sessionDigest(resolution);

      expect(digest, contains('Implementar'));
      expect(digest, contains('done'));
      expect(digest, contains('MARCADOR-SALIDA'));
      expect(digest, contains('Auditar'));
      expect(digest, contains('pending'));
      expect(digest.length, lessThanOrEqualTo(kSessionDigestMaxChars));
    });
  });

  group('reusableDependencyId', () {
    String executionIdFor(String nodeId) => 'workflow:s:$nodeId';

    test('elige la dependencia cerrada del mismo dueño con sesión viva', () {
      final chosen = reusableDependencyId(
        node: deliver,
        nodes: resolution.nodes,
        ownerId: 'dev',
        ownerIdOf: (id) => resolution.nodes
            .firstWhere((node) => node.id == id)
            .ownerProfileId,
        liveExecutionIds: {executionIdFor('implementation')},
        executionIdFor: executionIdFor,
        requiresIndependentOwner: false,
      );

      expect(chosen, 'implementation');
    });

    test('no reusa si el nodo exige dueño independiente, si el dueño es otro '
        'o si la sesión no está viva', () {
      String? pick({
        bool independent = false,
        String owner = 'dev',
        Set<String> live = const {'workflow:s:implementation'},
      }) => reusableDependencyId(
        node: deliver,
        nodes: resolution.nodes,
        ownerId: owner,
        ownerIdOf: (id) => resolution.nodes
            .firstWhere((node) => node.id == id)
            .ownerProfileId,
        liveExecutionIds: live,
        executionIdFor: executionIdFor,
        requiresIndependentOwner: independent,
      );

      expect(pick(independent: true), isNull);
      expect(pick(owner: 'auditor'), isNull);
      expect(pick(live: const {}), isNull);
    });
  });
}
