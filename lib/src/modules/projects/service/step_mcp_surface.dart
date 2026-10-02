import 'package:keel_e2e_panel/keel_e2e_panel.dart' show EngineConnection;

import 'package:keel_ui/src/modules/workflows/model/workflow_capability.dart';

/// La entrada MCP que un paso keel-e2e necesita, con las tools que le abre
/// (architecture §14, "Injection"): `mcp__keel-e2e` abre TODO el servidor,
/// el mismo patrón que ya usa `_runTurn` para un servidor MCP externo
/// completo (`mcp__<name>`).
class StepMcpSurface {
  const StepMcpSurface({this.entry, this.allowedTools = const []});

  /// `null` cuando el paso no declara keel-e2e, o es un turno de consulta:
  /// nada que mezclar en el mapa `mcpServers` del turno.
  final Map<String, dynamic>? entry;

  /// Vacío en los mismos casos que [entry].
  final List<String> allowedTools;
}

/// Nombre con el que un paso keel-e2e abre el servidor entero en claude
/// (`--allowedTools`), sin sufijo de tool individual.
const kKeelE2eMcpAllowedTool = 'mcp__$kKeelE2eMcpServerName';

/// Decide la superficie MCP de keel-e2e para EL TURNO de un paso
/// (architecture §14, "Injection"): pura, sin tocar el engine ni el disco.
///
/// `null` en cualquiera de los dos — nunca para un turno de consulta, nunca
/// para un nodo que no declaró `mcpServers: [kKeelE2eMcpServerName]`
/// (`capability.usesKeelE2e`) — deja [StepMcpSurface.entry] en `null`: el
/// caller nunca llama a esta función sin antes haber confirmado el attach,
/// así que [connection] siempre está disponible cuando sí corresponde.
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
