part of '../system_prompt.dart';

/// CUÁNTA DELEGACIÓN INTERNA se le permite al agente, y para qué.
///
/// Qué dice: con claude y un workflow que lo habilite, hasta N tareas
/// internas y solo para investigar, inventariar impacto o verificar; el
/// agente sigue siendo el único que escribe. Con cualquier otro proveedor o
/// con el cupo en cero, se resuelve el nodo en el hilo.
///
/// Quién lo usa: `_turnSystemPrompt` en `projects_viewmodel.dart`, en todos
/// los turnos.
/// Nothing an agent does may be invisible. The CLI can spawn subagents of its
/// own, which run outside the channel, cost money, and answer to nobody the
/// user registered — so they are forbidden outright, and the way to get a
/// specialist is to declare it and have the app register it in the open.
String subagentPolicyPrompt({
  required AgentProvider provider,
  required int maxSubagents,
}) {
  if (provider != AgentProvider.claude || maxSubagents == 0) {
    return 'Este proveedor no tiene delegación interna habilitada en este '
        'workflow. Resolvé el nodo en este hilo.';
  }
  return 'SUBAGENTES CONTROLADOS: podés abrir hasta $maxSubagents tareas '
      'internas, únicamente para investigación, inventario de impacto o '
      'verificación independiente. Sus resultados quedan visibles en el mapa. '
      'No les delegues implementación ni escritura: vos sos el único escritor '
      'y debés sintetizar su evidencia antes de cerrar el nodo.';
}
