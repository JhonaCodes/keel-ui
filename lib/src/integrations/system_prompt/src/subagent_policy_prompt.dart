part of '../system_prompt.dart';

/// CUÁNTA DELEGACIÓN INTERNA se le permite al agente, y para qué.
///
/// Qué dice: con claude y un workflow que lo habilite, hasta N tareas
/// internas POR NODO —lanzables en paralelo— y solo para investigar,
/// inventariar impacto o verificar; el agente sigue siendo el único que
/// escribe. Con cualquier otro proveedor o con el cupo en cero, se resuelve
/// el nodo en el hilo.
///
/// El cupo se declara acá porque el evento de apertura llega cuando el CLI YA
/// abrió el subagente: para entonces lo único que queda es cancelar la corrida
/// entera, que destruye el trabajo del nodo. Decirle el número por adelantado
/// es lo que hace que el tope se respete; `SubagentBudget` solo lo observa.
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
  final several = maxSubagents > 1;
  return 'SUBAGENTES CONTROLADOS: podés abrir hasta $maxSubagents tarea(s) '
      'interna(s) EN ESTE NODO, únicamente para investigación, inventario de '
      'impacto o verificación independiente. El cupo es por nodo: lo que '
      'gastes acá no se lo quitás al que sigue.'
      '${several ? ' Si son independientes entre sí, abrilas TODAS EN EL '
                'MISMO MENSAJE para que corran en paralelo — abrirlas de a una '
                'multiplica la espera sin mejorar la evidencia. Dales lentes '
                'distintos (correctitud, seguridad, reproducción) en vez de '
                'repetir la misma pregunta: la diversidad es lo que encuentra '
                'lo que una sola pasada no ve.' : ''}'
      ' Sus resultados quedan visibles en el mapa. No les delegues '
      'implementación ni escritura: vos sos el único escritor y debés '
      'sintetizar su evidencia antes de cerrar el nodo.';
}
