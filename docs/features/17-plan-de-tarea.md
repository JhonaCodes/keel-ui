# F17 — Plan de trabajo de una tarea

## Qué problema resuelve

Una tarea mostraba `3/7`: en qué paso del workflow está. Eso dice **quién
sigue**, no **qué falta de lo que se acordó**. El plan que escribe el
planificador en su paso vivía como un mensaje más del hilo: a los diez
turnos está enterrado, y no hay dónde volver a mirarlo ni forma de saber qué
se cumplió.

Son dos ejes distintos y por eso ahora se ven los dos. Un plan cumplido a
medias con el workflow en el paso 5 es información que no sale de ninguno de
los dos por separado.

## El modelo

`StationTask.plan`: una lista de `TaskPlanItem` (id, texto, hecho, quién lo
marcó). Se persiste con la tarea, en su mismo registro.

`setTaskPlan` reemplaza el plan **conservando el estado de los puntos cuyo
texto no cambió**: replanificar a mitad de camino no puede desmarcar lo que
ya se hizo.

## Cómo lo escribe un agente

Un servidor MCP local (`keel-plan`) montado en **todos** los turnos de
estación, sin depender de que el perfil tenga tools asignadas: el plan es
del canal, no del agente. La ruta lleva estación, tarea y perfil, así que un
turno solo puede tocar el plan de la tarea en la que corre.

| Tool | Cuándo |
|---|---|
| `set_task_plan(items)` | En el paso que planifica. Puntos concretos y verificables, no las etapas del workflow. |
| `complete_plan_items(items)` | Al cerrar el turno, con el texto exacto (o el id) de lo que ese paso resolvió. |

`complete_plan_items` acepta **texto o id**: el modelo tiene los dos a la
vista, y exigir el id convertiría un acierto en un fallo silencioso. Lo que
no encuentra vuelve nombrado en la respuesta, para que se corrija en el
turno siguiente en vez de descubrirse cuando el plan no avanza.

Un agente **codex** no recibe el plan — misma limitación que ya tiene con
tools y MCPs externos.

## En la UI

Debajo de la tarea abierta, en el sidebar. Solo la abierta: con cuatro
tareas en la estación, cuatro planes desplegados convierten la columna en
una pared.

- `✓` cumplido (tachado), `▸` el primer pendiente (lo que se está haciendo),
  `○` lo que falta.
- Click en un punto lo des/marca a mano: el veredicto final es del usuario.
- La cruz para sacar un punto aparece bajo el mouse — doce cruces
  permanentes son ruido.
