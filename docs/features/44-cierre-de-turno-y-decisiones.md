# F44 — Cierre de turno (`keel-outcome`), gates reales y decisiones pendientes

## Problema que resuelve

El motor no tenía forma de saber cómo terminó un turno. Deducía de la prosa:

- **«Sin texto» era fallo.** `ok = !turnFailed && answer.isNotEmpty`: un nodo
  que trabajó por tools y calló se registraba como hallazgo del compilador y
  quemaba una reformulación.
- **Los veredictos no existían para el motor.** Había 197 `VEREDICTO: GO` y
  `NO-GO` escritos en prosa en la base; ninguno movía un nodo. El
  `qualityGates` de la policy nunca se evaluaba.
- **No había «te está preguntando».** Un agente que cerraba el turno con una
  pregunta suelta dejaba la sesión sin nadie que supiera que esperaba. Peor:
  `PlanReadyBanner` saltaba igual («¿implementamos?») aunque solo hubiera
  preguntado.
- **El tope de turnos era fallo.** Llegar a `--max-turns` registraba un
  hallazgo y reformulaba el nodo, aunque el trabajo estuviera casi hecho.
- **La aprobación manual nunca disparó.** En los workflows guardados todo
  `manualApproval` era `optional`, y el motor solo instancia `required`.

## Decisión

**El bloque.** Todo turno de un nodo termina con:

```
```keel-outcome
status: done | blocked | needs_user | needs_permission | failed
summary: qué cambió y qué evidencia lo valida
files: rutas tocadas
artifacts: PR, comando de test, informe
verdict: GO | NO-GO         (obligatorio en nodos con output_contract audit-feedback)
next: id de capacidad opcional a activar
question: solo con needs_user / needs_permission
```
```

`parseKeelOutcome` (`modules/projects/model/turn_outcome_report.dart`) lee el
ÚLTIMO bloque válido del turno con el mismo `parseFencedBlocks` que
```cobertura. La spec viaja en el system prompt solo en turnos de nodo
(`kOutcomeProtocolPrompt`), nunca en consultas ni en chats 1:1.

**El motor decide con el bloque.** `ResolutionEngine.applyOutcome` es puro:

- `done` → nodo `done`, salida guardada en `WorkNode.output`, hallazgos
  asignados resueltos.
- auditoría con `NO-GO` → hallazgo `review` sobre el nodo auditado (o la
  primera dependencia), ese nodo vuelve a `pending`, la auditoría también
  (re-corre después de la corrección), `reviewCycleCount + 1`. La misma huella
  dos veces bloquea el caso.
- `blocked` / `failed` → hallazgo `contract` con el resumen, nodo reintentado
  hasta `maxReplans`.
- `needs_user` / `needs_permission` → nodo `paused` y una `SessionDecision`
  pendiente.
- `next` → el ViewModel activa la capacidad opcional con la ruta que ya
  existía (`activateWorkflowCapability`).

**Un seguimiento, no una adivinanza.** Un turno que cerró sin bloque —o una
auditoría sin veredicto— recibe UN turno de un paso sobre la misma sesión
(`kOutcomeFollowUpPrompt`) que solo pide el estado. Si aun así no hay bloque:
`done` con el texto como resumen si habló, `blocked` si calló. Una auditoría
que no da veredicto cuenta como `blocked`.

**El tope de turnos no es fallo.** `hitTurnCap` marca `capHit`, deja un mensaje
del sistema con el número, y el nodo pasa por el mismo seguimiento.

**Decisiones: un solo modelo de espera.** `SessionDecision`
(`kind: question | permission | approval`) vive en `Session.decisions`,
persistido. `Session.waitingForUser` es la señal. La tarjeta
`SessionDecisionCard` va sobre el composer, antes que el permiso post-hoc y que
el banner del plan, y `shouldAskToImplement` gana un `askedUser`: si el agente
preguntó, no se ofrece implementar.

**La respuesta llega al agente.** `answerSessionDecision` marca la decisión,
devuelve el nodo a `pending`, deja la respuesta en el hilo como mensaje del
usuario y llama a `resumeWorkflow`. Como la sesión del CLI se reanuda con el
prompt nuevo y no lee el hilo, las respuestas del nodo van dentro de su
instrucción («RESPUESTAS DEL USUARIO a lo que pediste antes»).

**`approvalRequired` en la capability.** Antes de correr un nodo que lo
declara, el motor crea una decisión `approval`, pausa el nodo y espera.
Aprobar lo corre; rechazar bloquea el caso ahí. Es la forma de pedir
aprobación para publicar sin un nodo aparte. `manualApproval` sigue existiendo
para lo guardado. Se edita en el formulario (switch) y en `create_workflow` /
`update_workflow` (`approval_required`).

**Los informes de auditoría viajan por lo declarado.** `_auditReportsFor` lee
primero `WorkNode.output` (veredicto, resumen, archivos) y cae al hilo solo
para nodos que cerraron antes de que el bloque existiera.

## Lo que no cambia

- `qualityGates` sigue siendo informativo; el gate real es el veredicto del
  nodo de auditoría.
- Los permisos siguen siendo post-hoc; `needs_permission` cierra el turno y
  espera. El permiso que suspende el proceso sin cerrar el turno es la fase
  siguiente, y reutiliza esta misma cola.
- Codex recibe la spec del bloque solo en el turno 1 de su sesión; el
  seguimiento la repite en su propio prompt. `--output-schema` queda para la
  fase de contexto y Codex.

## Cómo verificarlo

- `test/projects/turn_outcome_report_test.dart`: bloque embebido con NO-GO,
  el último bloque gana, variantes de estado, JSON.
- `test/projects/resolution_engine_test.dart` (`applyOutcome`): NO-GO →
  nodo auditado `pending` + hallazgo `review` + auditoría `pending` +
  `canComplete` falso; corrección + GO → hallazgo resuelto; `needs_user` →
  nodo pausado + decisión; `next`; `blocked`.
- `test/workflows/workflow_execution_test.dart`: las decisiones sobreviven
  al disco y `waitingForUser` refleja lo pendiente.
- `test/agents/plan_mode_test.dart`: `askedUser` apaga el banner del plan.
- En la app: un nodo que pregunta deja la tarjeta «ESPERÁNDOTE»; al contestar,
  el nodo re-arranca con la respuesta y sin volver a preguntar lo mismo.
