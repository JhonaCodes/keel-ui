# F6 — Proveedor codex por agente

## Qué es

Cada perfil/agente declara su **proveedor** (`AgentProvider`): `claude`
(default) o `codex`. El badge de dos letras junto al nombre del agente (CL
naranja / CX verde, sin trademarks) dice cuál CLI lo corre. Se elige en el
formulario del perfil (dropdown Proveedor) y Keel AI lo setea con
`create_or_update_agent(provider: "codex")`.

## Adaptador (`core/services/codex_cli_service.dart`)

Emite el MISMO stream de eventos (`ClaudeEvent`) que el adaptador claude —
los consumidores (chat 1:1, estaciones) son agnósticos del proveedor.

Verificado contra `codex-cli 0.142.3` con una corrida real:

- `codex exec --json` emite JSONL de la familia `thread.started` /
  `turn.started|completed|failed` / `item.*` / `error`. `thread_id` es el
  session id; resume: `codex exec resume <id> --json`.
- **codex lee stdin cuando no es TTY** ("Reading additional input from
  stdin…") — el adaptador cierra `process.stdin` inmediatamente o el
  proceso espera EOF para siempre.
- codex sale con código 0 incluso en errores in-band (`{"type":"error"}`)
  — el parser los convierte en fallo visible.
- Sin flag de system prompt → el prompt del perfil viaja como preámbulo
  delimitado del PRIMER turno; los resumidos lo conservan del historial.
- Sandbox: acceso total → `danger-full-access`, si no `workspace-write`.

## Modelos: cada proveedor con los suyos

Los dos CLIs no comparten NINGÚN nombre de modelo, así que el catálogo está
partido por proveedor en `agents/model/agent_model_option.dart`
(`modelOptionsFor(provider)`). Antes el selector ofrecía siempre los alias
de Claude — incluso a un agente codex, que además los ignoraba: elegir
"Opus 5" en un agente codex no hacía absolutamente nada.

Ahora:

- El selector del chat y el del formulario de perfil listan los modelos del
  proveedor del agente. Cambiar de proveedor en el formulario resetea el
  modelo al default de ese proveedor (un alias del otro no significa nada).
- La lista de codex sale de su propio catálogo,
  `~/.codex/models_cache.json`, filtrando `visibility: list` (lo mismo que
  ofrece su picker): `gpt-5.5`, `gpt-5.4`, `gpt-5.4-mini`. `gpt-reserve` y
  `codex-auto-review` están marcados `hide` y no se ofrecen. Si el lineup
  cambia, se actualiza esa constante.
- La primera opción es **"El de tu config de codex"** (alias vacío): no se
  pasa `-m` y codex resuelve el modelo de su `~/.codex/config.toml`. Es el
  default porque nunca queda obsoleta.
- El modelo SÍ viaja ahora: `codex exec -m <slug>`, tanto en el chat 1:1
  (`CodexCliService`) como en estaciones (el isolate arma sus propios
  argumentos y usa la misma regla).
- **Compatibilidad**: un agente codex creado antes de esta partición lleva
  un alias de Claude (`sonnet`). `codexModelArgument()` lo trata como "sin
  modelo" en vez de pasárselo a codex, que lo rechazaría; y el formulario
  arranca en el default de codex, así que guardar sana el registro.

## Límites v1 (a propósito)

- Sin tools deterministas, sin MCPs (externos ni keelai-actions), sin
  esfuerzo: esas superficies no existen en el adaptador. El formulario lo
  avisa. **El selector de esfuerzo del chat sigue visible para agentes
  codex y no hace nada** — mismo defecto que tenía el de modelo, todavía
  sin arreglar.
- El costo por turno se reporta 0 (codex no lo emite en el JSONL).

## Estaciones

`TaskRunSpec.provider` viaja al isolate, que elige ejecutable, argumentos y
dialecto de parseo (`_parseCodexEventToMessages`, espejo del servicio — el
isolate es auto-contenido por diseño).

## El plan de la tarea con codex

Codex no recibe servidores MCP, así que las tools del plan no existen para
él — y eso rompía el contrato central: si el dueño del paso 1 era codex, la
tarea corría sin plan y el cierre la sellaba "terminada". Tres piezas lo
arreglan:

- **Bloques fenced**: un miembro codex escribe el plan con un bloque
  ```` ```plan ```` (`puntos:` con líneas `texto | puesto`) y marca con
  ```` ```cumplido ```` — mismo patrón que ```` ```agente ````. La app los
  parsea al cerrar su turno (`_applyDeclaredPlanBlocks`) y aplica
  `setTaskPlan`/`completePlanItems` de verdad. La sección PLAN de su prompt
  documenta los bloques en vez de las tools.
- **Plan fresco en turnos resumidos**: codex recibe system prompt solo en
  el PRIMER turno de su sesión, así que el estado del plan quedaba congelado
  en el turno 1. Ahora, en turnos resumidos, la sección PLAN viva viaja
  antepuesta al pedido del turno, que sí llega siempre.
- **El verificador del cierre prefiere claude** (`_planCloser`): entre el
  dueño del primer y del último paso, va el que no corra con codex — tiene
  las tools de verdad. Si solo hay codex, verifica igual con los bloques.

Y el cierre con plan vacío ya no es un éxito automático: si el ciclo
terminó sin plan y sin producir un solo mensaje de trabajo, la tarea queda
como NO terminada en vez de "finished" — el falso éxito de una estación
codex muda desapareció.
