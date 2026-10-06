import 'package:keel_e2e_panel/keel_e2e_panel.dart' show EngineConnection;

import 'package:keel_core/core/host/keel_host.dart';
import 'package:keel_core/modules/workflows/model/workflow_capability.dart';

export 'package:keel_core/core/host/keel_host.dart' show StepMcpSurface;

/// Nombre con el que un paso keel-e2e abre el servidor entero en claude
/// (`--allowedTools`), sin sufijo de tool individual.
const kKeelE2eMcpAllowedTool = 'mcp__$kKeelE2eMcpServerName';

/// Decide la superficie MCP de keel-e2e para EL TURNO de un paso
/// (architecture §14, "Injection"): pura, sin tocar el engine ni el disco.
StepMcpSurface resolveStepMcpSurface({
  required WorkflowCapability? capability,
  required bool isConsult,
  required EngineConnection connection,
  required String projectId,
  required String sessionId,
  required String workNodeId,
  required String cwd,
}) {
  if (isConsult || capability == null || !capability.usesKeelE2e) {
    return const StepMcpSurface();
  }
  return StepMcpSurface(
    entry: {
      'type': 'http',
      'url': connection.mcpUrl(
        projectId: projectId,
        sessionId: sessionId,
        nodeId: workNodeId,
        cwd: cwd,
      ),
      'headers': {'Authorization': 'Bearer ${connection.mcpToken}'},
    },
    allowedTools: const [kKeelE2eMcpAllowedTool],
  );
}
