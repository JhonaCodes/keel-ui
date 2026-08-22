# F7 — Comunicación económica entre agentes + ledger de costos

## El contrato de direccionamiento (ya estructural, ahora documentado)

- **Identidad**: el handle del perfil (`@nombre`) es único en toda la app.
- **Ámbito**: una mención solo resuelve contra los MIEMBROS del proyecto
  de esa sesión (`membersOf`) — un handle de otro proyecto o un agente suelto
  jamás recibe el turno. Cada miembro además tiene su PROPIA sesión CLI por
  sesión (`sessionsByProfileId`), así que la dirección efectiva es
  `handle + sesión + proyecto/sesión` y dos proyectos no pueden pisarse.
- **Coordinación a costo cero**: el ruteo de menciones es DETERMINISTA
  (regex + tabla de miembros en `_resolveConsultations`), local y sin pasar
  por ningún modelo — no existe un "orquestador LLM" cobrando tokens por
  decidir quién habla. Lo único que cuesta tokens son los turnos reales de
  trabajo (1 mención = turno del consultado + continuación del que preguntó).
- **El código no es prosa**: un `@handle` adentro de un bloque o span de
  código no es una mención — el escaneo corre sobre el texto sin código
  (`stripCodeSpans`). Un diff con un handle en un comentario ya no dispara
  turnos.

## Frenos de costo

- `_maxConsultDepth = 3`, un par consultante→consultado por turno, y la
  continuación del que preguntó no puede abrir consultas nuevas (los
  ping-pong de cortesía no existen).
- **Presupuesto por turno raíz**: `_maxConsultsPerRootTurn = 5` contando
  toda la cadena. La profundidad no acota el ANCHO — con cinco miembros
  mencionándose entre sí un turno podía disparar decenas de turnos CLI.
  Al tope, las menciones restantes no disparan nada y el hilo lo dice.
- **El par inverso no rebota**: si A ya le consultó a B en este turno, la
  mención de B a A se ignora — la respuesta vuelve sola por la
  continuación. A→B→A muere ahí.
- Prompt de compañeros: "por cortesía nunca, por especialidad siempre".
- Fix de leak: `_consultedPairs` (keyed por turnId, que nunca se repite) se
  purga cuando no queda ninguna sesión corriendo.

## Qué recibe el consultado (mínimo contexto, ahora mecánico)

Antes el prompt pedía "formulá solo la pregunta" pero el código mandaba el
turno ENTERO del que consulta. Ahora viaja el EXTRACTO: los párrafos que
mencionan al handle más el inmediatamente anterior (`_consultExcerpt`, tope
~4k, con fallback al texto completo). El prompt de compañeros lo dice al
derecho: "la pregunta va en el párrafo de la mención — lo que no esté ahí,
el consultado no lo ve".

El consultado recibe además la MECÁNICA del ciclo: en qué paso va, cuáles
son SUS pasos (resueltos con la misma semántica rol/handle del flujo), y la
regla en tres casos — pasos futuros: no te adelantes; paso que ya pasó y
falta algo tuyo: resolvelo ACÁ (ese paso no vuelve); decisión de tu área:
tomala ahora. Antes "no te adelantes" y "resolvelo acá" eran indecidibles:
el consultado no tenía forma de saber si su paso ya había pasado.

Y la respuesta que vuelve al que preguntó es LO QUE DIJO el consultado
(el resultado real de su turno), no el último mensaje del hilo — que podía
ser un error o un aviso de sistema disfrazado de respuesta. Si la consulta
falla o vuelve vacía, la continuación no corre y el hilo lo dice.

Un turno de consulta corre SIN las tools del plan: el plan lo ve como
contexto y lo marca quien ejecuta el paso.

## Mencionar no es entregar el trabajo

Un paso que termina diciendo "corresponde ahora a @flutter-expert tomar el
RED" no está cerrando: está **abriendo una consulta**. El mencionado corre
ahí mismo, dentro del paso del que lo nombró, y hace el trabajo del paso
siguiente sin que el workflow avance — el tablero marca "paso 1 de 7,
Charter" mientras el RED ya está escrito, y no hay forma de saber dónde está
la sesión.

El turno lo dice explícitamente: al de más adelante no se lo menciona para
pasarle trabajo; el workflow le da la palabra cuando el paso termina.

**El desempate** — el caso frecuente en que el especialista ES el del paso
siguiente, que antes quedaba entre dos reglas que chocaban ("derivá por
especialidad siempre" vs "nunca menciones al del paso siguiente") — es una
sola pregunta: ¿tu paso puede cerrarse sin su respuesta? Si sí, no lo
menciones — decí qué dejás listo y cerrá. Si no, consultalo con solo la
pregunta que te falta.

## La economía de los ciclos (desde F17)

Un punto del plan = una vuelta completa del workflow: un plan de 6 puntos
en un flujo de 7 pasos son hasta 42 turnos de trabajo, más consultas. Por
eso el prompt insiste en que un punto es una UNIDAD ENTREGABLE, no una
sesión de media hora — el tamaño del punto es el multiplicador del costo. Y
por eso un paso que falla corta el ciclo en vez de arrastrar el error por
los pasos restantes.

## Ledger de costos (lo que se ve, se controla)

- `StationTask.costUsd` + `costByProfileId`: acumulados de cada
  `TaskTurnCompleted`, persistidos con la sesión.
- UI: el header de la sesión muestra el total (`US$X.XX`) junto al contexto;
  el tooltip del subtítulo desglosa por miembro.
- Limitación conocida: los turnos codex reportan costo 0 (su JSONL no lo
  emite).
