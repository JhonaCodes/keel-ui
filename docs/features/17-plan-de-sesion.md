# F17 — Plan de trabajo de una sesión

## Qué problema resuelve

Una sesión mostraba `3/7`: en qué paso del workflow está. Eso dice **quién
sigue**, no **qué falta de lo que se acordó**. El plan que escribe el
planificador en su paso vivía como un mensaje más del hilo: a los diez
turnos está enterrado, y no hay dónde volver a mirarlo ni forma de saber qué
se cumplió.

Son dos ejes distintos y por eso ahora se ven los dos. Un plan cumplido a
medias con el workflow en el paso 5 es información que no sale de ninguno de
los dos por separado.

## El modelo

`StationTask.plan`: una lista de `TaskPlanItem` (id, texto, hecho, quién lo
marcó). Se persiste con la sesión, en su mismo registro.

`setTaskPlan` reemplaza el plan **conservando el estado de los puntos cuyo
texto no cambió**: replanificar a mitad de camino no puede desmarcar lo que
ya se hizo. La comparación es NORMALIZADA (`normalizeForMatch`: minúsculas,
sin acentos, espacios colapsados, sin puntuación final) — exigir el texto
EXACTO convertía un retoque de redacción en un desmarque, y el ciclo volvía
a trabajar lo que ya estaba hecho. `complete_plan_items` compara igual.

## Cómo lo escribe un agente

Un servidor MCP local (`keel-plan`) montado en **todos** los turnos de
proyecto, sin depender de que el perfil tenga tools asignadas: el plan es
del canal, no del agente. La ruta lleva proyecto, sesión y perfil, así que un
turno solo puede tocar el plan de la sesión en la que corre.

| Tool | Cuándo |
|---|---|
| `set_task_plan(items)` | Cuando la sesión no tiene plan. Puntos concretos y verificables, no las etapas del workflow. |
| `complete_plan_items(items)` | Al cerrar el turno, con el texto exacto (o el id) de lo que ese paso resolvió. |

**El turno lleva el plan escrito, no solo las tools.** Nombrarlas no
alcanzaba, por dos motivos que se vieron en uso:

- `complete_plan_items` pide "el texto exacto" de puntos que el agente nunca
  había visto — no había forma de leer el plan.
- "si tu paso es planificar" era una interpretación, y el paso 1 de `tdd` se
  llama **Charter**: el planificador no se dio por aludido y la sesión corrió
  entera sin plan.

Ahora el turno trae el plan renderizado con su estado (`[x]` / `[ ]`), y la
regla es mecánica: **si la sesión no tiene plan, lo escribe quien esté
hablando, sea cual sea su paso**. Un turno de consulta ve el plan como
contexto pero no lo escribe ni lo marca — contesta y se va.

`complete_plan_items` acepta **texto o id**: el modelo tiene los dos a la
vista, y exigir el id convertiría un acierto en un fallo silencioso. Lo que
no encuentra vuelve nombrado en la respuesta, para que se corrija en el
turno siguiente en vez de descubrirse cuando el plan no avanza.

Un agente **codex** no tiene las tools (no recibe servidores MCP), pero el
plan ya no le es ajeno: lo escribe con un bloque ```` ```plan ````
(`puntos:` con líneas `texto | puesto`) y marca con ```` ```cumplido ````,
que la app parsea al cerrar su turno — mismo patrón que ```` ```agente ````.
Y como codex solo recibe system prompt en el primer turno de su sesión, en
los turnos resumidos la sección PLAN viva viaja antepuesta al pedido, para
que no trabaje contra un plan congelado en el turno 1 (ver F6).

Un turno de CONSULTA tampoco lleva las tools del plan — no solo la
instrucción: la tool no está. El consultado ve el plan como contexto y lo
marca quien ejecuta el paso.

## Un punto del plan = una vuelta del workflow

El flujo era **una sola pasada**. Con un plan de siete puntos, el paso 1
planificaba el primero, la implementación hacía ese, y al llegar al último
paso no había forma de volver a planificar los seis que quedaban. Lo que se
veía en el canal era esto:

> **rust-expert**: no implemento sin los charters de los ítems restantes —
> eso es el paso 1.
> **planificador**: correcto, el charter es mi paso, no esta consulta.

Los dos tenían razón y la sesión no avanzaba. No era el prompt del
planificador ni faltaba un agente: faltaba la vuelta.

Ahora, con puntos pendientes y la sesión detenida, **"continuar" arranca otro
ciclo completo desde el paso 1, acotado al próximo punto**. Está como palabra
escrita en el canal y como una barra pegada **arriba del campo de escribir**,
que dice cuál es el punto que sigue y a qué puesto le toca.

Esa barra vivía antes al fondo del sidebar, debajo de la lista de puntos, y
ahí no la encontraba nadie: el sidebar es la columna del CONTEXTO, y una
acción escondida al final del contexto es una acción que no existe. Las
acciones se buscan donde uno está escribiendo. Sólo
si el mensaje es corto y no dice nada más: *"continuá pero primero mirá el
endpoint X"* es un mensaje para quien tiene la palabra, no un ciclo nuevo.

Las palabras tienen dos niveles. **"Continuar"** (y un "seguí con el
siguiente punto" explícito) vale siempre — es la palabra que enseñan el
botón y el mensaje de cierre. **"dale" / "sigue" / "ok" pelados** solo
cuentan cuando lo último del hilo es la invitación del cierre: en cualquier
otro momento, responder "dale" a una pregunta de un agente es una respuesta
a ese agente — antes lanzaba un ciclo entero por accidente.

El ciclo lleva **el pedido original de la sesión** (guardado en
`StationTask.request` en la primera corrida — sin eso, un miembro que entra
recién en el ciclo 3 nunca sabía qué se pidió) más el punto como único
trabajo, y le dice al flujo que siga en la misma rama y el mismo PR sin
volver a empezar (el contrato completo de entrega vive en la sección
ENTREGA del prompt, ver F19).

Dos mecánicas más del ciclo:

- **Handoff entre pasos**: el hilo nunca viaja al CLI, así que el paso N
  recibe "lo que dejó dicho @anterior al cerrar el paso N-1" (el resultado
  real de su turno, recortado), y cada paso cierra diciendo en dos líneas
  qué deja listo. Antes el paso N no veía NADA del N-1.
- **Un paso que falla corta el ciclo** y la sesión queda como no terminada,
  con la invitación a corregir y retomar. Antes el flujo marchaba los N
  pasos fallando en cadena sobre un turno muerto.

## A quién le toca cada punto

`set_task_plan` acepta `{texto, puesto}`. El **puesto**, no el handle — igual
que en los pasos del workflow, así el mismo plan sirve en el proyecto de Rust
y en la de Flutter, donde ese puesto lo ocupa otro agente. Se ve en el
sidebar bajo cada punto y viaja en el turno como `[ ] (implementador) …`.

Eso es el "quién hace qué": trabajo del planificador, no de un agente nuevo.

## El cierre se decide contra el plan, no contra los pasos

Un workflow puede recorrer sus siete pasos enteros y dejar la mitad de lo
acordado sin hacer, y hasta ahora eso se sellaba como "terminada": el
contador decía 7/7 y nadie miraba el plan. *El flujo terminó* no es *la sesión
está hecha*.

Ahora, cuando el último paso cierra:

- **Plan completo** → sesión terminada.
- **Quedan puntos** → vuelve **una** vez al verificador (el dueño del
  primer paso; si ese puesto está vacante, el del último; entre los dos se
  prefiere el que no corra con codex, que tiene las tools del plan de
  verdad) con la lista exacta de lo pendiente. Su trabajo ahí es verificar **contra el código**, no contra
  lo que se dijo en el hilo: marcar lo que sí está hecho, sacar del plan lo
  que dejó de corresponder explicando por qué, y dejar sin marcar lo que falta
  de verdad diciendo a qué puesto le toca. No implementa: verifica.
- **Si después de eso todavía falta algo** → la sesión NO queda terminada, y el
  mensaje de cierre nombra qué falta.

Ese turno corre con las consultas cerradas. Cerrar no es reabrir el trabajo:
si el verificador arrastra a los demás, la sesión vuelve a correr entera por la
puerta de atrás.

Una sesión sin plan no tiene nada que verificar y cierra como siempre — otra
razón por la que el plan se escribe sí o sí en el primer turno. Con una
excepción honesta: si el ciclo terminó **sin plan y sin producir un solo
mensaje de trabajo**, la sesión queda como NO terminada — "terminó sin nada"
no puede sellarse igual que "todo cumplido".

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

Debajo de la sesión abierta, en el sidebar. Solo la abierta: con cuatro
sesiones en el proyecto, cuatro planes desplegados convierten la columna en
una pared.

- `✓` cumplido (tachado), `▸` el primer pendiente (lo que se está haciendo),
  `○` lo que falta.
- Click en un punto lo des/marca a mano: el veredicto final es del usuario.
- La cruz para sacar un punto aparece bajo el mouse — doce cruces
  permanentes son ruido.
