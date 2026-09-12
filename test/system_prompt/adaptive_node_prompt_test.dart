import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/system_prompt/system_prompt.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_case.dart';
import 'package:keel_ui/src/modules/projects/model/work_node.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

void main() {
  final workflow = Workflow(
    id: 'w',
    name: 'resolver',
    whenToApply: 'todo',
    createdAt: DateTime(2026),
  );
  const node = WorkNode(
    id: 'deliver',
    kind: WorkNodeKind.custom,
    ownerRole: 'implementador',
    title: 'Entregar',
    instruction: 'Abrí el PR.',
    dependencyIds: ['implementation'],
  );
  const resolution = ResolutionCase(
    id: 'case',
    ownerRole: 'implementador',
    status: ResolutionCaseStatus.active,
    nodes: [node],
  );

  test('lleva lo que dejaron las dependencias y el estado del caso, y no '
      'reinventa el pedido', () {
    final prompt = adaptiveNodePrompt(
      request: 'PEDIDO-ORIGINAL',
      workflow: workflow,
      resolution: resolution,
      node: node,
      dependencyContext: '[Implementar] MARCADOR-SALIDA\nArchivos: lib/a.dart',
      digest: '- Implementar (done): MARCADOR-DIGEST',
    );

    expect(prompt, contains('PEDIDO-ORIGINAL'));
    expect(prompt, contains('MARCADOR-SALIDA'));
    expect(prompt, contains('lib/a.dart'));
    expect(prompt, contains('MARCADOR-DIGEST'));
    expect(
      prompt.indexOf('MARCADOR-SALIDA'),
      lessThan(prompt.indexOf('keel-outcome')),
    );
  });

  test('sin dependencias cerradas no agrega secciones vacías', () {
    final prompt = adaptiveNodePrompt(
      request: 'PEDIDO',
      workflow: workflow,
      resolution: resolution,
      node: node,
    );

    expect(prompt, isNot(contains('LO QUE DEJARON')));
    expect(prompt, isNot(contains('ESTADO ACTUAL DEL CASO')));
  });
}
