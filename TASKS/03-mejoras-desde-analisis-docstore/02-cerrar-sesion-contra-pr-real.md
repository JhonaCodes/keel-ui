---
estado: libre
titulo: Una sesión puede cerrar "finished" sin que exista un PR real
---

# Una sesión puede cerrar "finished" sin que exista un PR real

## Qué hay que hacer

El cierre de una sesión pasa exclusivamente por `ProjectsViewModel._closeAgainstPlan`
(`lib/src/modules/projects/viewmodel/projects_viewmodel.dart:1197-1310`). Si
`plan.pending` está vacío al terminar el workflow, la sesión se marca `finished` de
inmediato **sin ninguna ronda de verificación** (líneas 1207-1233) — se confía en que
las llamadas previas del propio agente al MCP tool `complete_plan_items`
(`session_plan_mcp_server.dart:231-307`) fueron honestas. Solo si quedan puntos
pendientes corre un turno extra de un agente LLM (`_planCheckPrompt`, líneas
2954-2984) que verifica "contra el código en disco" — no contra estado real de
git/GitHub.

La creación de rama y PR (`_deliveryPrompt`, líneas 106-119) es una instrucción de
prompt: el propio agente corre `gh pr create --draft` en su turno de shell. No hay
código Dart que la orqueste ni que la confirme. La única lectura de un PR en la app es
`lastPullRequestIn` (`lib/src/shared/utils/links.dart:15-77`), un regex sobre el texto
del último mensaje del hilo, usado solo para mostrar un chip clickeable
(`session_chat_view.dart:456-469, 620-649`) — sin ningún fetch de estado. Grep
exhaustivo confirmó: cero llamadas a `api.github.com`, cero `Process.run`/
`Process.start` invocando `gh` desde el código de cierre, cero campos persistidos tipo
`branches:`/`prs:`/`closed_by:`.

**Por qué esto es más grave de lo que suena a nivel de especificación**: la brecha
tiene dos capas, no una. (1) Si el plan ya quedó marcado 100% `done` por el propio
agente, la ronda de verificación **nunca corre** — es exactamente el patrón "`status:`
escrito una vez y nunca revisitado" que Loop 2 (`docs/the-closed-loop.md`) identifica
como la falla fundacional que motivó todo su diseño. (2) Incluso cuando la ronda sí
corre, "verificar contra el código" no es lo mismo que "verificar contra
git/GitHub" — el agente lee archivos locales que pueden reflejar commits sin push y
sin PR abierto en absoluto.

**Escenario de falla concreto**: un agente termina el ciclo de código, llama a `gh pr
create --draft` como le indica `_deliveryPrompt`, pero el comando falla en silencio
(token vencido, rate limit, el remoto rechaza el push). El agente no relee la salida
con cuidado, y como los cambios sí quedaron commiteados localmente, llama igual a
`complete_plan_items` marcando "abrir PR" como `done`. `plan.pending` queda vacío →
`_closeAgainstPlan` cierra `finished` sin correr ninguna verificación. El usuario ve la
sesión en verde creyendo que hay un PR draft esperando review; `lastPullRequestIn`
nunca encuentra una URL porque nunca se creó, así que ni siquiera aparece el chip.
Cero señales de que falta algo. El trabajo queda huérfano hasta que el usuario, por su
cuenta, entra al repo y descubre que no hay PR ni rama remota.

**Diseño recomendado** — NO trasplantar el sistema completo de trackers/frontmatter de
los documentos (sería sobre-ingeniería para una app interactiva de sesiones). Portar
solo el principio: no cerrar sobre autodeclaración, cerrar sobre evidencia mínima
verificable.

1. Cuando `plan.pending` queda vacío y el plan contenía un ítem de tipo
   "shipear/abrir PR" (detectable porque `_deliveryPrompt` lo exige), no cerrar
   `finished` directo: correr una verificación barata y determinística (`gh pr view
   <n> --json state`, o un fetch simple sobre el PR ya parseado por
   `lastPullRequestIn`) para confirmar que el PR realmente existe y sigue abierto —
   **no** que esté mergeado; el merge lo sigue decidiendo el usuario, nunca el cierre
   automático.
2. Si esa verificación falla (PR inexistente, `gh pr create` falló en silencio, o no
   hay ningún PR parseable pese a que `_deliveryPrompt` lo pedía), **no marcar la
   sesión como `failed` duro** — marcarla con una señal visible tipo "sin evidencia de
   PR", delegando la decisión final a un humano. Un chequeo que no pudo confirmar nada
   se reporta como no verificado, nunca como limpio ni como roto.

**Riesgo**: bajo-medio. El riesgo principal es meter una dependencia de red/auth
(`gh`/API de GitHub) en la ruta de cierre: si falla por causas ajenas (rate limit,
timeout), debe degradar a "no verificado", nunca hacer fallar duro la sesión. El
riesgo de alcance es replicar el ladder completo de 6 estados
(`ready_to_close`/`orphan`/`dormant`/sweep programado) — la propia doc de origen
admite que gran parte de eso sigue **planned** incluso en su propio sistema; replicar
de más acá sería importar complejidad no validada en el dominio de origen.

## Bloqueantes

Ninguno.

## Criterio de aceptación

- [ ] `_closeAgainstPlan` corre una verificación determinística de existencia de PR
      cuando el plan incluía un ítem de entrega de código, ANTES de cerrar `finished`
      — incluso si `plan.pending` ya está vacío.
- [ ] La verificación confirma "el PR existe y está abierto", nunca intenta confirmar
      merge (eso sigue siendo decisión del usuario).
- [ ] Si la verificación falla o no puede correr (red, auth, rate limit), la sesión
      queda en un estado visible distinto de `finished` y distinto de `failed` duro —
      el usuario ve explícitamente "sin evidencia de PR", no un falso verde.
- [ ] Test que reproduzca el escenario de falla descripto arriba (plan marcado done
      sin PR real) y confirme que la sesión YA NO cierra `finished` en ese caso.
- [ ] Regresión: el flujo normal (PR creado con éxito) sigue cerrando `finished` sin
      fricción extra visible para el usuario.
