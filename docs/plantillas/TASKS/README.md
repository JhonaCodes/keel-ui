# <Objetivo final del proyecto>

Una o dos frases: qué queda cierto cuando TODO esto esté hecho. No la lista
de tareas — el estado del mundo al final.

## Carpetas

El número manda el orden en que hay que tomarlas.

| Carpeta | Qué cubre | Estado |
|---|---|---|
| `01-nombre-alusivo` | … | en curso |
| `02-siguiente` | … | pendiente |

## Cómo se trabaja acá

1. `list_roadmap_tasks` para ver qué hay y qué está tomado.
2. `claim_task` sobre la que vayas a hacer. Si falla, otro se te adelantó:
   pasá a la siguiente, no insistas.
3. Al terminar: `estado: hecho` en el archivo de la tarea, y `release_task`.

No hay archivo de seguimiento ni de tomadas. El estado vive arriba de cada
tarea —así dos agentes que terminan cosas distintas no chocan— y quién la
tiene tomada vive en keel-ui, que es lo único que necesita ser atómico.
