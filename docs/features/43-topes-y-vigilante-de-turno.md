# F43 — Topes por defecto, vigilante de turno y retome tras interrupción

## Problema que resuelve

Un workflow podía quedarse trabado sin ninguna señal. Cuatro causas, todas en
código:

- **Sin tope real de turnos.** `maxAgenticTurns: 0` significaba «ilimitado», y
  26 de 31 workflows guardados corrían así. Un nodo llegó a 577 turnos.
- **Sin ningún timeout.** Un CLI colgado no emite eventos; el `await for` del
  turno esperaba para siempre y la sesión quedaba `running` con nada corriendo.
  La única salida era Stop a mano. Un run quedó 1 h 51 min en ese estado.
- **Interrumpir rompía el flujo.** Un mensaje enviado a mitad de nodo llamaba a
  `stopSession`, que sellaba la sesión como `failed`, dejaba el nodo en
  `running` y no volvía nunca a `_runWorkflow`. El motor solo elige nodos
  `pending`, así que el caso «no cerraba».
- **Un fallback que no podía escribir.** Cuando Claude no abría el subagente
  nativo, el nodo caía a una sesión externa con `planMode: true` fijo. Un nodo
  de entrega (commit, push, PR) no podía escribir jamás y quemaba su tope
  explicando por qué.

Y sin techo de costo: una sesión gastaba lo que el modelo quisiera.

## Decisión

**Topes por defecto en la capacidad.** `WorkflowCapability.effectiveMaxAgenticTurns`
es lo que llega a `--max-turns`: el declarado, o 20 si el nodo escribe y 8 si
es de solo lectura. `maxAgenticTurns` sigue guardando lo que el usuario escribió;
cero ya no es «ilimitado».

**Plazos y techo en la policy.** `WorkflowPolicy` suma `idleTimeoutMinutes`
(10), `nodeTimeoutMinutes` (45) y `maxSessionCostUsd` (20; 0 = sin techo). Se
editan en el formulario del workflow y se dicen en el mensaje de preflight, para
que un corte no sea una sorpresa. Registros anteriores leen los defaults.

**Vigilante de turno.** `TurnWatchdog` (`modules/projects/service/`) envuelve el
stream de eventos con dos plazos: uno de inactividad, que cada evento reinicia,
y uno duro para el turno entero. Cualquiera dispara una sola vez, cancela el
proceso y cierra el stream: `_runTurn` sale del `await for` y marca el turno
fallido con el motivo y el número puesto. Tiene `pause`/`resume` para el turno
que espera una decisión humana: esa espera no es inactividad del agente.

**Techo de costo.** Al elegir cada nodo, el motor compara lo gastado
(`SessionUsage.reportedCostUsd`) con el techo. Si lo alcanzó, bloquea el caso,
lo dice y sella la sesión. Lo que queda viaja a claude como `--max-budget-usd`
para que corte solo. Solo cuenta el costo que el proveedor informa: codex no lo
informa, y el preflight lo advierte.

**Interrupción que retoma.** `stopSession(interrupting: true)` cancela el turno,
devuelve el nodo `running` a `pending` (`ResolutionEngine.releaseRunningNodes`)
y no sella la sesión. El mensaje se atiende como follow-up y, al terminar,
`resumeWorkflow` vuelve a `_runWorkflow` si el caso sigue activo y tiene un nodo
listo. Un Stop pelado sigue sellando `failed`. Y un turno cortado por Stop o
interrupción ya no se registra como hallazgo del compilador.

**Fallback con el modo del nodo.** La sesión externa de un `providerSubagent`
corre con `planMode: capability.readOnly`, no con `true` fijo.

**Salidas selladas.** El tope de ciclos de auditoría sella la sesión como
`failed` antes de salir. La aprobación manual queda `running` a propósito: es
una espera, y el estado «te espera» llega con el protocolo de cierre de turno.

**El stdin de claude se cierra al arrancar.** `claude -p` con un stdin que no
es TTY espera unos segundos por si el prompt llega por ahí y, al vencer, escribe
«Warning: no stdin data received…» en stderr. El runner no cerraba el stdin (el
de codex sí), así que cada turno pagaba esa espera y, cuando el turno salía con
código distinto de cero —el tope de turnos, por ejemplo—, ese aviso era el
«error» que aparecía en el hilo en lugar del motivo real. Ahora el stdin se
cierra apenas arranca el proceso; el test lo prueba con un CLI falso POSIX que
detecta si su stdin sigue abierto (el `read -t` de bash devuelve 1 al vencer en
el bash 3.2 de macOS, así que no sirve como sonda).

**Rondas de tools por API.** El default baja de 200 a 40. Cada ronda reenvía el
historial completo; 200 rondas por nodo era el multiplicador de costo. El
constructor sigue aceptando más para el caso que lo necesite.

## Lo que no cambia

- Ningún modelo se elige por el motor: el perfil manda.
- Los permisos siguen siendo post-hoc en esta entrega; el permiso bloqueante es
  la siguiente.
- `askProject` y las respuestas en hilos de requerimiento ya registraban al
  ledger; no hacía falta tocarlas.

## Cómo verificarlo

- `test/projects/turn_watchdog_test.dart`: inactividad, plazo duro, pausa, y un
  stream que termina solo.
- `test/workflows/workflow_model_test.dart`: tope efectivo y policy con plazos
  que sobreviven al disco.
- `test/projects/resolution_engine_test.dart`: soltar el nodo en curso deja el
  caso activo con el nodo `pending`.
- `test/llm/claude/claude_arguments_test.dart`: `--max-budget-usd` solo con
  techo.
- `test/llm/claude/claude_cli_runner_test.dart`: el CLI falso no ve el stdin
  abierto y el aviso no llega al mensaje de fallo.
- En la app: interrumpir un workflow con un mensaje; el hilo dice que retoma, el
  follow-up corre y el nodo vuelve a arrancar sin que la sesión quede `failed`.
