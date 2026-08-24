# F15 — Keel AI con catálogo completo

## Objetivo

Keel AI administra la misma arquitectura que ejecuta la app. No razona desde
archivos JSON, backups ni registros históricos: sus tools de lectura toman los
modelos tipados y el estado vivo de los ViewModels.

El dominio es generalista. Un proyecto puede contener cualquier tecnología o
incluso trabajo no relacionado con programación. El stack detectado sirve para
seleccionar skills, reglas y conocimiento; nunca es un default global ni obliga
a crear una topología fija de agentes.

## Ciclo de trabajo

1. `list_catalog` lista skills, reglas, hooks, tools, agentes, workflows,
   proyectos, MCPs y bases de conocimiento mediante resúmenes breves.
2. `list_workflows` devuelve todos los contratos de workflow completos en una
   sola llamada. El filtro opcional `names` limita la respuesta a nombres
   exactos e informa cuáles no existen.
3. `list_projects` devuelve la configuración completa de todos los proyectos,
   incluidos los workflows disponibles y activo, asignaciones y sesiones. Al
   compararla con `list_workflows` aparecen referencias anteriores o inválidas.
4. `get_item` devuelve el contrato completo de un objeto individual afectado.
5. `describe_system` muestra operación e integridad: secretos, MCPs bloqueados,
   sesiones activas y referencias inválidas.
6. Keel AI calcula el impacto mínimo, reutiliza lo existente y muta en orden de
   dependencias.
7. Lee nuevamente cada objeto y vuelve a comprobar la integridad. Una respuesta
   “creado” no basta si el conjunto quedó incompleto.

Las tools de lectura no agregan burbujas al hilo. Las mutaciones sí dejan una
nota visible en el momento en que ocurren.

Antes de cada tool, el servidor espera a que terminen de cargar los catálogos
tipados. El primer turno de la aplicación no puede recibir una lista parcial ni
escribir sobre un snapshot vacío mientras la persistencia se inicializa.

## Lectura completa

`get_item` expone todo lo que afecta la ejecución:

- agente: ID, rol, prompt, proveedor, modelo, esfuerzo, skills, reglas, hooks,
  tools, MCPs, conocimiento y permiso de constructor;
- workflow: intención, tipo, responsable, skills por turno y de preflight,
  reglas, conocimiento, gates, límites, `buildsRoadmap` y todas las capacidades
  con instrucción, dependencias, activación e independencia;
- proyecto: miembros con motor efectivo, workflows, workflow activo, reglas,
  hooks, conocimiento, sesiones, overrides de motor y asignaciones por nodo;
- hook: evento, matcher, cuerpo, timeout, reglas garantizadas, alcance y estado.

El inspector marca IDs colgantes, requisitos inexistentes, nodos que ya no
pertenecen al workflow y asignaciones a perfiles ausentes.

`list_catalog(kind: "workflows")` sigue siendo el índice rápido de nombres.
Para analizar el conjunto completo se usa `list_workflows`; para editar uno en
particular, `get_item`. Keel AI también dispone de `create_workflow` y
`update_workflow`, de modo que lectura, creación y modificación son contratos
explícitos y verificables.

Para responder qué proyectos todavía usan una configuración anterior, Keel AI
lee `list_projects` y `list_workflows` en la misma transacción. No necesita
recorrer manualmente cada nombre ni inspeccionar JSON persistido.

## Construcción adaptativa

Un workflow declara capacidades, no una cadena posicional. Cada capacidad tiene
ID estable, título, instrucción, rol, dependencias, activación `required` u
`optional` y un indicador `independent`.

- `required` entra al grafo inicial; `optional` se activa solo por evidencia.
- El responsable integra el caso y existe un único escritor.
- `independent` exige un perfil diferente a quienes produjeron sus
  dependencias. Como las sesiones CLI se guardan por perfil, la auditoría
  obtiene también un contexto separado.
- Una skill de auditoría es una instrucción, no evidencia independiente.
- Compilador, linter, test, contrato o revisión crean un hallazgo sobre el nodo
  afectado; repetir la misma huella sin cambios no es progreso.

Los defaults de auditoría son opcionales e independientes. Keel AI no agrega un
roster fijo de planificador, diagnosticador, implementador y varios auditores:
cada perfil y nodo debe justificar tokens, contexto y handoff.

## Mutaciones disponibles

- `create_or_update_agent` admite Claude, Codex, OpenRouter y DeepSeek, modelo,
  esfuerzo, skills, reglas, hooks, tools, MCPs y conocimiento. Cambiar proveedor
  sin modelo normaliza al default del proveedor nuevo.
- `create_workflow` y `update_workflow` escriben el contrato adaptativo completo.
- `create_project` y `update_project` administran miembros, workflows, reglas,
  hooks, conocimiento y modo mantenido/solo lectura.
- `update_project(member_engines)` guarda proveedor/modelo/esfuerzo por miembro
  y proyecto; `node_assignments` guarda el agente concreto de cada capacidad.
- `unassign_from_agent` puede retirar cualquiera de las dependencias aditivas.

Las referencias se validan contra el catálogo real. Los nombres desconocidos se
rechazan o se informan explícitamente; nunca quedan silenciosamente como si
estuvieran inyectados.

## Fallback declarativo

Los bloques fenced existen únicamente si el MCP de acciones no aparece. Su
representación de capacidad es:

```text
id|título|rol|required|dependencia-a+dependencia-b|shared|instrucción
id|título|rol|optional|implementation|independent|auditar evidencia
```

La forma anterior de seis campos se rechaza: el dominio persistido y las
entradas de Keel AI no contienen APIs lineales, shims ni código deprecated.
