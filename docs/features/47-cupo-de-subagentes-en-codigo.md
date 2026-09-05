# F47 — El cupo de subagentes se aplica en código

## Problema que resuelve

El cupo de subagentes por nodo (`WorkflowPolicy.maxSubagents`) era una
promesa del prompt. `SubagentBudget` lo observaba: cuando llegaba el evento
de apertura, el CLI ya había lanzado el subagente y lo único posible era
avisar una vez y pagarlo entero. Un nodo con cupo 1 podía abrir cuatro; un
nodo con cupo 0 podía abrir uno. Y los subagentes sin una pregunta concreta
hacían trabajo sin sentido porque nadie les había pedido nada verificable.

## Decisión

**Un hook `PreToolUse` sobre `Task`.** `keel-subagent-guard`
(`integrations/hook_delivery/src/subagent_guard.dart`) se agrega a cada turno
de un agente claude, junto a los hooks del usuario y al gate de permisos
(F45). Cuenta en `subagents.count`, un archivo del workspace 0700 del turno
—muere con el turno—, y deniega la tarea `N+1` con el motivo. Cupo cero
deniega desde la primera, que es lo que el prompt siempre dijo y nunca pudo
garantizar. Solo claude tiene la tool `Task`; para codex y las APIs no hay
nada que frenar y el hook no se agrega.

**El prompt sigue siendo la primera línea.** `subagentPolicyPrompt` dice
ahora que el cupo se aplica en código y que cada tarea tiene que llevar una
pregunta concreta y un contrato de salida: una tarea sin pregunta es cupo
tirado. `SubagentBudget` queda como observador para el mapa y el log.

## Cómo verificarlo

- `test/hooks/subagent_guard_hook_test.dart`: claude recibe el hook con
  matcher `Task`; el script, corrido con bash de verdad, deja pasar dos y
  deniega la tercera y la cuarta; con cupo cero deniega; sin cupo no hay hook.
- En la app: un nodo con `maxSubagents: 1` que intenta abrir dos tareas ve la
  segunda denegada con «Cupo de subagentes agotado» en el hilo del CLI.
