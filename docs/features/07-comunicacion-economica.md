# F7 — Comunicación económica entre agentes + ledger de costos

## El contrato de direccionamiento (ya estructural, ahora documentado)

- **Identidad**: el handle del perfil (`@nombre`) es único en toda la app.
- **Ámbito**: una mención solo resuelve contra los MIEMBROS de la estación
  de esa tarea (`membersOf`) — un handle de otra estación o un agente suelto
  jamás recibe el turno. Cada miembro además tiene su PROPIA sesión CLI por
  tarea (`sessionsByProfileId`), así que la dirección efectiva es
  `handle + sesión + estación/tarea` y dos estaciones no pueden pisarse.
- **Coordinación a costo cero**: el ruteo de menciones es DETERMINISTA
  (regex + tabla de miembros en `_resolveConsultations`), local y sin pasar
  por ningún modelo — no existe un "orquestador LLM" cobrando tokens por
  decidir quién habla. Lo único que cuesta tokens son los turnos reales de
  trabajo (1 mención = turno del consultado + continuación del que preguntó).

## Frenos de costo

- `_maxConsultDepth = 3`, un par consultante→consultado por turno, y la
  continuación del que preguntó no puede abrir consultas nuevas (los
  ping-pong de cortesía no existen).
- Prompt de compañeros: "por cortesía nunca, por especialidad siempre" +
  NUEVO: al consultar, formular SOLO la pregunta concreta con el mínimo
  contexto — no pegar razonamiento ni historial.
- Fix de leak: `_consultedPairs` (keyed por turnId, que nunca se repite) se
  purga cuando no queda ninguna tarea corriendo.

## Ledger de costos (lo que se ve, se controla)

- `StationTask.costUsd` + `costByProfileId`: acumulados de cada
  `TaskTurnCompleted`, persistidos con la tarea.
- UI: el header de la tarea muestra el total (`US$X.XX`) junto al contexto;
  el tooltip del subtítulo desglosa por miembro.
- Limitación conocida: los turnos codex reportan costo 0 (su JSONL no lo
  emite).
