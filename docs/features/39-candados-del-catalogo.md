# F39 — Candados: lo que una tool no puede tocar sola

## Qué problema resuelve

Keel AI y los agentes con acceso al catálogo pueden crear, actualizar y
borrar skills, reglas, tools, agentes, workflows, proyectos, hooks, MCPs,
tableros, secrets y bases de saber. Es el punto de la app. Pero hay cosas que
funcionan y que no se tocan: la regla que hace que el equipo escriba tests
antes, el agente que ya está afinado, el proyecto de producción.

Un candado no te frena a vos: **frena a las tools**. Un agente que quiera
cambiar o borrar un ítem bloqueado tiene que pedirte permiso primero,
diciendo qué va a cambiar y por qué (`change_intent` / `change_reason`), y
vos ves ese pedido en el hilo antes de que pase nada.

## Cómo se identifica un candado

Por el par `(tipo, nombre)`, no por el id: `skill:tdd-workflow`,
`rule:sin-fuerza-bruta`, `mcp_server:github`. Es lo que se ve en la UI y lo
que un agente escribe en una tool, y sobrevive a que el ítem se guarde de
nuevo.

Los tableros son la excepción, porque solo son únicos dentro de un proyecto:
su nombre de candado es `proyecto · tablero`.

Renombrar un ítem **mueve** su candado: si no, renombrar sería la forma
trivial de sacarlo.

## Un candado que se pone solo

`lock_registry:registry` existe siempre y se re-crea si falta. Es lo que hace
que **poner o sacar un candado con una tool** también pida permiso — sin él,
el primer movimiento de un agente que quiere cambiar algo protegido sería
desbloquearlo.

Por eso en la pantalla aparece aparte, bajo «Del sistema», y sin botón.

## Dónde se ven todos juntos

El candado se pone desde cada ítem, con el botón de su fila. Sacarlo era
también de a uno, lo que con doce catálogos significa que para acordarte de
qué protegiste tenías que recorrerlos todos.

**Ajustes → Elementos bloqueados** muestra la lista completa, agrupada por
tipo, con desbloqueo en el lugar. Es exactamente lo que ve un agente cuando
llama `list_locked_items`: la misma data, no una copia.

## Verificación

1. Bloquear una regla desde su tile: el botón queda cerrado y editar y
   borrar quedan deshabilitados.
2. Abrir Ajustes → Elementos bloqueados: la regla aparece bajo REGLA.
3. Desbloquear desde el panel: desaparece de la lista y su tile vuelve a
   permitir editar.
4. Sin nada bloqueado, el panel explica para qué sirve un candado en vez de
   mostrar una lista vacía.
5. El registro del sistema se ve siempre y no tiene botón para sacarlo.
