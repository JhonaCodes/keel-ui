import 'package:flutter_test/flutter_test.dart';
import 'package:keel_e2e_panel/keel_e2e_panel.dart';

import 'package:keel_ui/src/modules/projects/service/step_mcp_surface.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow_capability.dart';

void main() {
  const connection = EngineConnection(
    port: 51234,
    pid: 999,
    mcpToken: 'tok-123',
    controlToken: 'ctrl-456',
  );

  const declaresE2e = WorkflowCapability(
    id: 'e2e-run',
    title: 'E2E',
    instruction: 'Correr escenarios.',
    role: '*',
    mcpServers: [kKeelE2eMcpServerName],
  );

  test(
    'un paso que declara keel-e2e recibe la entrada http con su url y '
    'token, y la tool del servidor entero',
    () {
      final surface = resolveStepMcpSurface(
        capability: declaresE2e,
        isConsult: false,
        connection: connection,
        projectId: 'p1',
        sessionId: 's1',
        workNodeId: 'e2e-run',
        cwd: '/repo',
      );

      expect(surface.entry, {
        'type': 'http',
        'url': connection.mcpUrl(
          projectId: 'p1',
          sessionId: 's1',
          nodeId: 'e2e-run',
          cwd: '/repo',
        ),
        'headers': {'Authorization': 'Bearer tok-123'},
      });
      expect(surface.allowedTools, ['mcp__keel-e2e']);
    },
  );

  test('un turno de consulta nunca recibe keel-e2e, aunque el nodo lo declare', () {
    final surface = resolveStepMcpSurface(
      capability: declaresE2e,
      isConsult: true,
      connection: connection,
      projectId: 'p1',
      sessionId: 's1',
      workNodeId: 'e2e-run',
      cwd: '/repo',
    );

    expect(surface.entry, isNull);
    expect(surface.allowedTools, isEmpty);
  });

  test('un nodo que no declaró keel-e2e no recibe nada', () {
    const other = WorkflowCapability(
      id: 'diagnosis',
      title: 'Diagnóstico',
      instruction: 'Investigar.',
      role: '*',
    );

    final surface = resolveStepMcpSurface(
      capability: other,
      isConsult: false,
      connection: connection,
      projectId: 'p1',
      sessionId: 's1',
      workNodeId: 'diagnosis',
      cwd: '/repo',
    );

    expect(surface.entry, isNull);
    expect(surface.allowedTools, isEmpty);
  });
}
