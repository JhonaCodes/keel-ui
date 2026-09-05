# F48 — Keel AI supervisa a pedido, lint de workflows, plantilla de cuatro nodos

## Problema que resuelve

Keel AI podía leer sesiones, pero solo los últimos mensajes con previsualizaciones
de 400 caracteres: no veía el caso (nodos, cierres, hallazgos, costo) ni las
decisiones pendientes, y no tenía cómo contestar una ni cómo mandar una
instrucción a una sesión que estaba corriendo. Y armaba workflows redundantes:
la plantilla por defecto traía once nodos, en la base había 156 oraciones
repetidas entre instrucciones, `validateWorkflowCapabilities` solo miraba ids,
dependencias y ciclos, y las invariantes («no agregues dos auditores por
costumbre») vivían en el prompt.

## Decisión

**Cuatro tools nuevas, solo a pedido del usuario.**

- `inspect_session(project, session, full)`: estado, costo, pedido, caso con
  tabla de nodos (id, título, estado, dueño, intentos, costo, último cierre con
  veredicto), resumen determinista (`sessionDigest`, F46), hallazgos abiertos,
  decisiones pendientes con su id, y con `full` los últimos 20 mensajes sin
  recortar y los subagentes con resultado.
- `intervene(project, session, text)`: si la sesión corre, encola e interrumpe
  (el nodo retoma después, F43); si no, abre el turno siguiente. Queda marcado
  como puesto por Keel AI en nombre del usuario.
- `answer_decision(project, session, decision_id, answer | approve, scope)`:
  contesta una decisión pendiente (F44/F45) con lo que el usuario decidió.
- `lint_workflow(capabilities)`: el lint sin crear nada.

El prompt de Keel AI tiene una sección «REVISAR UNA SESIÓN»: inspeccionar
primero, opinar con evidencia (puede desmentir el cierre que un agente declaró
si los mensajes muestran otra cosa), actuar solo con la decisión del usuario.
No hay disparador automático: Keel AI no interviene por su cuenta.

**Lint en código.** `lintWorkflowCapabilities`
(`modules/workflows/model/workflow_capability.dart`) corre en
`createWorkflow`/`updateWorkflow` (los errores rechazan) y en `lint_workflow`:

| Severidad | Regla |
|---|---|
| error | más de 8 nodos requeridos |
| error | `manualApproval` con `activation: optional` (nunca se instancia) |
| error | nodo que audita (rol auditor/revisor, o solo lectura sobre un nodo que escribe) sin `outputContract: audit-feedback` |
| warning | más de 6 nodos en total |
| warning | dos nodos con el mismo rol y contrato casi idéntico (Jaccard ≥ 0,8) |
| warning | nodo que escribe sin tope declarado |
| info | nodo requerido sin dependencias que no es el primero |

**Plantilla de cuatro nodos.** General y bug: `plan` (solo lectura, 6 turnos)
→ `implement` (20) → `audit` (sesión propia, dueño independiente,
`audit-feedback`, 6) → `deliver` (reanuda la sesión de `implement`, 6,
`approvalRequired`). Sin nodos de corrección: el NO-GO devuelve el nodo
auditado solo (F44). La auditoría corre en sesión propia y no como subagente
nativo: el subagente falló en 149 corridas y el fallback era el que auditaba.

**Migración.** Conserva inventario de impacto y matriz de cobertura, sin
nodos de corrección: `planner → impact → implementation → code-audit → tests
→ test-audit → verification (approvalRequired)` más `device-e2e` opcional.
Siete requeridos: pasa el lint.

Los 31 workflows guardados conservan sus capacidades; el lint solo actúa al
crear o actualizar.

## Lo que no cambia

- Keel AI sigue sin recibir hooks ni el gate de permisos.
- No hay botón «pedile a Keel AI que revise» en el header de la sesión: se
  le pide desde su chat con el nombre del proyecto y la sesión (o pegando una
  referencia de mensaje).

## Cómo verificarlo

- `test/workflows/workflow_lint_test.dart`: la forma de la plantilla vieja da
  error por cantidad y por aprobación opcional, warning por auditorías
  duplicadas y nodos sin tope; la nueva pasa limpia y son cuatro nodos.
- `test/assistant/keel_ai_supervisor_tools_test.dart`: `inspect_session`
  muestra nodos, cierres y la decisión con su id; `answer_decision` la
  contesta; `lint_workflow` señala la aprobación opcional.
- `test/workflows/workflow_execution_test.dart` y
  `test/projects/resolution_engine_test.dart` actualizados a las plantillas
  nuevas.
