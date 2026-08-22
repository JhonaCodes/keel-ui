# F15 — Keel AI con los ojos abiertos

## El problema

Keel AI tenía 19 tools y **una sola de lectura** (`list_secret_names`). Podía
crear, actualizar por creación y borrar, pero no podía **ver** nada: ni qué
skills existían, ni el contenido de una, ni cómo estaba configurado un
agente, ni el estado del sistema.

El síntoma diario era este: *"creá un agente experto en flutter usando los
skills que tenemos registrados"* → *"no tengo una tool para listar los
skills, ¿me pasás los nombres?"*.

Y había un agravante silencioso: `create_or_update_agent` no validaba los
nombres que recibía, así que un nombre inventado quedaba como asignación
colgada — el agente creía tener esa skill y en el turno no le llegaba nada.

## Las tres capas que faltaban

**Ojos** — leer lo que existe:

| Tool | Devuelve |
|---|---|
| `list_catalog(kind?)` | Nombre + para qué sirve de skills, reglas, tools, agentes, workflows, proyectos y MCPs. Sin `kind`, todo |
| `get_item(kind, name)` | El contenido **completo**: el texto de una skill, el código de una tool, la config de un agente o un proyecto |
| `describe_system()` | Estado: repos configurados, secrets sin valor, MCPs que no van a levantar, agentes respondiendo, sesiones corriendo |

**Manos** — corregir sin destruir:

| Tool | Para qué |
|---|---|
| `update_skill` / `update_rule` | Reemplazar contenido sin borrar y recrear |
| `update_tool` | Cambiar descripción, código, runtime, timeout o secrets. Lo que se omite queda como estaba |
| `update_workflow` | Cambiar cuándo aplica y/o los pasos |
| `unassign_from_agent` | **Sacar** skills/reglas/tools/MCPs. `create_or_update_agent` solo SUMA |

**Proyectos** — el límite que el propio prompt declaraba:

| Tool | Para qué |
|---|---|
| `update_station` | Propósito, directorio, miembros, workflows disponibles, reglas y cuál queda ACTIVO |
| `manage_station_documents` | Sumar o sacar documentos de negocio — antes solo se podía desde el formulario |
| `open_project_session` | Abrir una sesión y mandarle el pedido al canal. Mismo camino que usa la Jobs API: `createTask` + `sendToChannel`, fire-and-forget |

Total: 19 → **30 tools**.

## Detalles que hacen que funcione

**La allowlist manda.** `kKeelAiMcpToolNames` es lo que viaja como
`extraAllowedTools` al CLI: una tool definida pero ausente de esa lista
existe y no se puede llamar. Las 30 definiciones y las 30 entradas de la
allowlist tienen que coincidir.

**Las tools de lectura no dejan rastro en el hilo.**
`dispatchKeelAiTool` agrega una nota de sistema por cada llamada, para que
el usuario vea la mutación en el momento. Un listado no muta nada: su
respuesta ya viaja al modelo por el resultado, y ponerla además como
burbuja solo ensucia. El conjunto `_readOnlyTools` marca cuáles se saltean.

**Nada de asignaciones colgadas.** `executeAgentAction` filtra
skills/reglas/tools/MCPs contra el catálogo real: asigna las que existen,
descarta las que no y **las nombra en la respuesta**, para que el modelo se
entere de que inventó un nombre. Lo mismo para las reglas de un proyecto,
que también pasaban sin verificar.

**Los updates reemplazan, no fusionan.** Por eso el prompt ordena leer con
`get_item` antes de actualizar: sin eso se pisa el contenido anterior. Y
renombrar rompe asignaciones (van por nombre), así que las tools lo dicen
en su propia descripción.

**Nada de lo que existe en el VM se reimplementó.** `updateSkill`,
`updateRule`, `updateTool`, `updateWorkflow`, `updateStation`,
`addDocument`/`removeDocument`, `setActiveWorkflow`, `createTask` y
`sendToChannel` ya estaban en los ViewModels: lo único que faltaba era
exponerlos.

## El prompt

De nada sirve una tool que el modelo no sabe que tiene. `kKeelAiSystemPrompt`
ahora abre con **"mirá antes de actuar"** y tres reglas:

1. Antes de **asignar**, listar. Nunca inventar un nombre.
2. Antes de **actualizar**, leer con `get_item`.
3. Antes de decir **"no puedo"**, fijarse si hay tool. Casi siempre la hay.

Y el mapa del sistema cambió su cierre: donde decía *"no hay forma de sumar
documentos a un proyecto desde una conversación"* ahora dice que todo se
puede leer, crear, actualizar y corregir hablando — sin depender de que
alguien abra un formulario.
