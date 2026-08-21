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
| `set_task_plan(items)` | Cuando la tarea no tiene plan. Puntos concretos y verificables, no las etapas del workflow. |
| `complete_plan_items(items)` | Al cerrar el turno, con el texto exacto (o el id) de lo que ese paso resolvió. |

**El turno lleva el plan escrito, no solo las tools.** Nombrarlas no
alcanzaba, por dos motivos que se vieron en uso:

- `complete_plan_items` pide "el texto exacto" de puntos que el agente nunca
  había visto — no había forma de leer el plan.
- "si tu paso es planificar" era una interpretación, y el paso 1 de `tdd` se
  llama **Charter**: el planificador no se dio por aludido y la tarea corrió
  entera sin plan.

Ahora el turno trae el plan renderizado con su estado (`[x]` / `[ ]`), y la
regla es mecánica: **si la tarea no tiene plan, lo escribe quien esté
hablando, sea cual sea su paso**. Un turno de consulta ve el plan como
contexto pero no lo escribe ni lo marca — contesta y se va.

`complete_plan_items` acepta **texto o id**: el modelo tiene los dos a la
vista, y exigir el id convertiría un acierto en un fallo silencioso. Lo que
no encuentra vuelve nombrado en la respuesta, para que se corrija en el
turno siguiente en vez de descubrirse cuando el plan no avanza.

Un agente **codex** no recibe el plan — misma limitación que ya tiene con
tools y MCPs externos.

## En la UI — dos vistas, no una

**En el hilo** queda escrito lo que se acordó, para leerlo entero:

```
🤖 PLAN DE TRABAJO · 6 puntos
   ○  Función pura de agregación con expected/variance
   ○  Test RED que falla contra el oráculo declarado
   …
```

y cada vez que un paso cierra puntos, su acuse:

```
🤖 PLAN · 3 de 6
   ✓  Test RED que falla contra el oráculo declarado
```

Replanificar no pisa lo anterior: escribe otro bloque, marcado como
`PLAN REPLANIFICADO`, y la conversación conserva las dos versiones. El
acuse por paso existe para que "dice que lo hizo pero no lo tildó" se vea en
el momento y no tres turnos después.

**En el sidebar** vive el plan VIVO, que es la otra pregunta: qué falta
ahora.

Debajo de la tarea abierta, en el sidebar. Solo la abierta: con cuatro
tareas en la estación, cuatro planes desplegados convierten la columna en
una pared.

- `✓` cumplido (tachado), `▸` el primer pendiente (lo que se está haciendo),
  `○` lo que falta.
- Click en un punto lo des/marca a mano: el veredicto final es del usuario.
- La cruz para sacar un punto aparece bajo el mouse — doce cruces
  permanentes son ruido.
