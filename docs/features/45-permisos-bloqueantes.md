# F45 — Permisos y preguntas que suspenden el turno

## Problema que resuelve

El permiso llegaba tarde y valía demasiado. El CLI corría sin nadie que le
contestara: una tool no permitida se denegaba sola y el turno seguía. Keel
recién se enteraba por el evento de denegación, mostraba una tarjeta, y
«Permitir» hacía dos cosas malas a la vez: cambiaba un setting **global de la
app** (a partir de ahí todos los agentes tenían esa tool, siempre) y arrancaba
un turno **nuevo** con «retomá donde te quedaste», que re-pagaba el contexto y
re-derivaba el trabajo. Un segundo pedido de la misma tool se tragaba en
silencio, la tarjeta no se persistía y solo se mostraba una a la vez.

Y un agente que necesitaba un dato del usuario no tenía más remedio que cerrar
el turno preguntando (F44 le dio `needs_user` para eso), perdiendo el proceso
vivo.

## Decisión

**Un gate que espera, en los tres proveedores.** `keel-decision-gate` es un
hook `PreToolUse` interno que Keel agrega a cada turno de un miembro sobre las
tools que escriben (`Bash`, `Edit`, `Write`, `MultiEdit`, `NotebookEdit`). El
script (Python, viene con macOS) manda `{tool_name, tool_input}` al servidor
loopback de decisiones y **se queda esperando** la respuesta; devuelve el
contrato `permissionDecision: allow | deny` que entienden claude y codex, y que
el bridge de las APIs ahora también lee de la salida del hook. Plazo del hook:
seis horas, el mismo criterio que `kMcpToolTimeoutMillis`. Si Keel no contesta,
es deny, nunca allow por defecto.

Con el gate puesto, esas tools entran a la allow-list del CLI —si no, el CLI las
deniega solo, sin preguntar— y es el gate el que decide. Un proyecto que no
mantenés sigue sin tools de escritura; una consulta tampoco las recibe.

**Grants con alcance.** El gate contesta al instante si el permiso ya está
concedido en alguno de tres niveles, y si no encola una decisión y espera:

| Alcance | Dónde queda | Quién lo decide |
|---|---|---|
| Solo esta vez | en ningún lado | la tarjeta |
| Esta sesión | `Session.grantedTools` | la tarjeta |
| Este agente acá | `Project.grantedToolsByProfileId` | la tarjeta |
| Siempre | `AppSettings.extraAllowedTools` (lo que antes era el único nivel) | la tarjeta o Ajustes |

**`ask_user`.** El servidor de decisiones expone además un MCP
(`keel-decisions`) con una sola tool: `ask_user(question, options)`. Suspende
el turno hasta la respuesta y la devuelve en el mismo turno, con el proceso y
el contexto vivos. `needs_user` (F44) sigue como fallback para el que no puede
llamar tools (codex no recibe MCPs).

**Una sola cola.** Las dos cosas crean una `SessionDecision` (F44) con
`blocking: true`: hay un proceso vivo esperando. El vigilante del turno se
pausa mientras tanto (esperar a una persona no es inactividad del agente) y se
reanuda al contestar. `answerSessionDecision` completa la espera y sigue; para
las decisiones no bloqueantes (nodo cerrado con `needs_user`, aprobación) hace
lo de F44: destraba el nodo y retoma el workflow.

**Stop y reinicio.** Detener la sesión contesta lo pendiente con `cancelled`:
el hook recibe deny y nadie queda esperando. Al reabrir la app, una decisión
bloqueante pendiente se cancela (el proceso que esperaba murió con la app); una
no bloqueante sobrevive, porque el nodo está pausado en disco.

**Servidor.** `DecisionGateServer` (`integrations/decisions_mcp/`): un solo
proceso loopback con token por arranque. `POST /gate/{proyecto}/{sesión}/
{perfil}` para el hook y `POST /ask/{proyecto}/{sesión}/{perfil}` para el MCP.
La ruta lleva el alcance, como los demás MCP propios: un turno no puede pedir
permiso en nombre de otro. `tools/call` no tiene plazo del lado del servidor.

## Límites conocidos

- **Codex.** Desde F51 el gate viaja por `-c hooks.PreToolUse=[...]` en exec
  y en resume, con `--dangerously-bypass-hook-trust`: sin ese flag codex
  0.153 ignora en silencio un hook generado por turno (verificado con el
  binario). El contrato del hook es el mismo que el de claude.
- **Las denegaciones de hooks del usuario** (`kHookDenialMarker`) siguen
  siendo post-hoc por diseño: un guardarraíl que bloquea no pregunta.
- El banner viejo de permiso post-hoc queda para el caso que el gate no cubre
  (una tool MCP fuera de la allow-list); «Permitir» ahí sigue siendo global.

## Cómo verificarlo

- `test/hooks/decision_gate_hook_test.dart`: claude recibe el `PreToolUse`
  con matcher de escritura, plazo largo y script con `permissionDecision`;
  codex lo recibe como override `-c`; sin gate y sin catálogo no hay hooks.
- `test/projects/session_decision_queue_test.dart`: dos pedidos encolan dos
  decisiones; conceder «esta sesión» completa solo la primera y queda en
  `grantedTools`; el mismo tool ya no pregunta; Stop cancela la otra; una
  pregunta bloqueante devuelve el texto contestado.
- En la app: un agente hace `git push`; el proceso queda vivo (`ps`), la
  tarjeta ESPERÁNDOTE muestra el comando, «Esta sesión» lo deja pasar y no
  vuelve a preguntar por `Bash` en esa sesión.
