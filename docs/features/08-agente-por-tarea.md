# F8 — Agente temporal por tarea

## Qué es

Una tarea de proyecto puede sumar agentes SOLO para ella
(`StationTask.extraProfileIds`), sin tocar el roster del proyecto: las
demás tareas no los ven, no aparecen como compañeros en sus prompts y sus
menciones no resuelven ahí. Para tener un agente en TODAS las tareas se
modifical proyecto (formulario / keelai), como siempre.

## Mecánica

- `membersOf(Station, {StationTask? task})` = miembros del proyecto ∪
  extras de la tarea. TODOS los puntos de turno pasan la tarea: resolución
  de rol por paso, follow-up owner, consultas `@handle`, prompt de
  compañeros, reanudación tras permiso, askAboutLine y recordManualEdit.
- Las declaraciones ```agente que un miembro hace a mitad de conversación
  ahora suman al TASK (antes: al proyecto) — el perfil global se registra
  igual (reusable), pero la membresía queda acotada a esa conversación. El
  mensaje del hilo lo dice: "incorporó a @x a ESTA tarea".
- VM: `addAgentToTask` / `removeAgentFromTask` (solo extras; los miembros
  de proyecto no se quitan desde acá).

## UI

Botón de persona+ en el header de la tarea → panel "Agentes de esta tarea"
con tres secciones: miembros del proyecto (solo lectura), extras de la
tarea (con quitar), y registrados disponibles para sumar.
