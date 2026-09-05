# F46 — Contexto entre nodos, reuso de sesión y presupuesto del prompt

## Problema que resuelve

Cada nodo empezaba de cero. Un nodo `newSession` abría una sesión de CLI nueva
y recibía solo el pedido original, su contrato y los hallazgos en una línea:
la salida del nodo anterior no viajaba (solo con `outputContract:
audit-feedback`, que ningún workflow guardado usaba). `resumeParent`, el único
executor que conservaba contexto, lo usaban cero workflows. Resultado: `audit`
y `deliver` volvían a leer el repo que `implement` acababa de recorrer; un
nodo llegó a 248 millones de tokens de lectura de caché.

Además el system prompt no tenía techo: skills y reglas enteras, un perfil
con 37 mil caracteres; `_subagentPacket` mandaba las skills, reglas y system
prompt del auditor dentro de la instrucción y el fallback los volvía a mandar
como system prompt. Y codex perdía la identidad en cada resume: el preámbulo
solo iba en el turno 1, y `exec resume` descartaba el sandbox y el perfil de
hooks.

## Decisión

**La salida viaja.** Con el bloque de cierre (F44) cada nodo deja
`WorkNode.output`. `dependencyOutputs` + `renderDependencyOutputs`
(`modules/projects/service/node_context.dart`) arman la sección «LO QUE
DEJARON LOS NODOS DE LOS QUE DEPENDÉS» de la instrucción: título, veredicto,
resumen, archivos y artefactos, cada uno recortado a 1.500 caracteres. Cuando
hay nodos cerrados que no son dependencias directas va además «ESTADO DEL
CASO HASTA ACÁ»: `sessionDigest`, determinista, nodo por nodo, sin cuerpos
del hilo, hasta 4.000 caracteres.

**Reuso de la sesión del dueño.** Con `WorkflowPolicy.reuseOwnerSession`
(default true), un nodo `newSession` cuyo dueño ya cerró una dependencia
reanuda la sesión de CLI de esa dependencia (`reusableDependencyId`: mismo
dueño, dependencia cerrada, sesión viva, y el nodo no exige dueño
independiente; se mira de la última dependencia a la primera). El hilo lo
dice. El seguimiento de un turno (F44) cae en la misma sesión porque la
elección es determinista.

**Compactación sin LLM.** Antes de reanudar (reuso o `resumeParent`), si
`Session.contextUsageRatio` supera `compactAtContextRatio` (default 0.7), se
descarta esa sesión de CLI y el nodo arranca fresco con la salida de sus
dependencias y el digest en la instrucción. El resumen es la compactación; no
hay un turno extra ni un modelo distinto.

**Presupuesto del system prompt.** `_turnSystemPrompt` arma secciones con
prioridad de recorte (`PromptSection`, `budgetTurnSystemPrompt` en
`turn_prompt.dart`): el brief de saber sale primero (3), después las skills
asignadas que la policy no exige (2), después las skills globales más allá de
las dos primeras (1). Identidad, reglas, skills requeridas y contratos nunca.
Techo `systemPromptMaxChars` (default 60.000). Cuando recorta, `Log.w` dice
cuánto medía y qué sacó. El saber y el plan siguen al final, para el prefijo
cacheable.

**Codex en resume.** `buildCodexArguments` manda `-c sandbox_mode=...` y `-c
profile=...` al reanudar (verificado: `exec resume` acepta `-c`), así el modo
plan tiene freno y el perfil de hooks —con el gate de permisos de F45— aplica
también en turnos reanudados. Y el preámbulo de rol ya no se descarta: el
ViewModel manda la versión COMPACTA del prompt (identidad, reglas y contratos;
sin skills ni saber, que ya están en el hilo de codex) y `buildCodexPrompt` la
antepone en cada turno. Los avisos «reanudó sin sandbox ni perfil» se fueron
porque dejaron de ser verdad.

**Paquete de auditoría más chico.** `_subagentPacket` lleva el contrato, los
archivos tocados y la instrucción; no las skills, reglas ni system prompt del
auditor, que ya viajan como su system prompt cuando cae al fallback.

## Lo que no cambia

- `resumeParent` explícito sigue ganando sobre el reuso implícito.
- `--allowedTools` no cambia entre nodos de la misma sesión reanudada (ya
  era así para `resumeParent`).
- `-c profile=` en codex no está verificado con el binario (la CLI del
  usuario no acepta sus modelos hoy); si codex ignora la clave, el resume
  corre sin hooks como antes, no peor.

## Cómo verificarlo

- `test/projects/node_context_test.dart`: salidas de dependencias con
  recorte, digest, y la elección de sesión a reusar (mismo dueño, cerrada,
  viva; nunca con dueño independiente).
- `test/system_prompt/adaptive_node_prompt_test.dart`: la salida de la
  dependencia y el digest entran antes del contrato de cierre.
- `test/projects/turn_prompt_test.dart`: el presupuesto saca primero el saber,
  después las skills; reglas e identidad sobreviven.
- `test/llm/codex/codex_arguments_test.dart` y `codex_cli_runner_test.dart`:
  `-c sandbox_mode`, `-c profile`, preámbulo en resume, sin aviso.
- `test/workflows/workflow_model_test.dart`: los tres campos nuevos de la
  policy sobreviven al disco.
- En la app: en una sesión de dos nodos del mismo agente, el segundo dice
  «reanuda la sesión de …» y su costo de entrada baja respecto de una sesión
  con `reuseOwnerSession: false`.
