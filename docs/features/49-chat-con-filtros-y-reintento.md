# F49 — El chat con filtros, subagentes a la vista, reintento y turno vivo persistido

## Problema que resuelve

El hilo de una sesión era un solo stream sin ninguna navegación: con cuatro
agentes y doscientos mensajes la única forma de ver «qué dijo el auditor» era
scrollear. Los subagentes no existían en el chat (solo en el Mapa). El chip de
cada mensaje decía `nodo de resolución: code-audit`, el id crudo. Un mensaje de
error del motor no ofrecía nada más que «escribí algo». Y el turno vivo no se
guardaba: al reabrir la app a mitad de turno, la sesión aparecía corriendo con
nadie corriendo, y lo razonado se perdía. Encima, con Opus, «pensando» sin
texto parecía un cuelgue.

## Decisión

**Filtros en la vista.** `ThreadFilter` (`modules/projects/model/thread_entry.dart`)
acota el hilo por autor, por nodo, con o sin mensajes del sistema, con o sin
subagentes. Es estado local de la lista, no de la sesión. Con un autor
elegido, el sistema es ruido y se oculta; los mensajes del usuario se ven
siempre. La barra de chips aparece cuando hay más de un miembro o hay nodos.

**Subagentes en el hilo.** `buildThreadEntries` acepta los subagentes de la
sesión y los intercala por hora de arranque (`ThreadSubagent`), renderizados
por `SessionSubagentCard`: tipo, padre, pedido, fase, tiempo y el resultado
plegado. Verlos donde se lee la conversación es lo que muestra un padre que
abrió tres tareas sin pregunta.

**Título en vez de id.** `nodeTitleFor(workflow, nodeId)` resuelve el título
de la capacidad (con los alias viejos); el chip dice «paso: Auditar» y el
divisor de cambio de nodo dice «sigue Entregar».

**Reintentar paso.** Un mensaje de error del motor sobre un nodo, con la
sesión parada y el caso sin cerrar, ofrece «Reintentar «título»».
`retryWorkNode` → `ResolutionEngine.retryNode` (nodo a `pending`, caso a
`active`) → `resumeWorkflow`. Vale para el corte del vigilante, un caso
bloqueado y el turno que murió al cerrar la app.

**Turno vivo persistido.** `SessionLiveTurn` tiene JSON y viaja en
`Session.toJson`. Al revivir (`revivedSession`), un turno que quedó vivo se
convierte en un mensaje del sistema con la fase y lo razonado hasta ahí, y se
limpia. La sesión ya no aparece corriendo con nadie corriendo.

**«Pensando» sin texto.** La tira de turno vivo dice «pensando (este modelo no
expone su razonamiento en vivo)» cuando la fase es pensar y no llegó texto:
no se puede forzar al CLI a emitirlo, pero sí decir que no es un cuelgue.

## Cómo verificarlo

- `test/projects/thread_entries_test.dart`: filtro por autor, por nodo, el
  subagente intercalado entre los mensajes que lo rodean, títulos de nodo.
- `test/projects/resolution_engine_test.dart`: `retryNode` devuelve el nodo a
  pendiente y el caso a activo.
- `test/workflows/workflow_execution_test.dart`: el turno vivo sobrevive al
  disco y al revivir queda como mensaje.
