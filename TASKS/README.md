# Roadmap de Keel UI

El objetivo final es que Keel UI permita trabajar con agentes de código de
forma gobernada y confiable: proveedores LLM intercambiables, turnos y
entregas verificables, y operaciones locales observables ante fallas.

Esta carpeta contiene únicamente trabajo planificado para alcanzar ese
estado. Cada tarea vive en un grupo numerado, se puede reclamar de manera
independiente y conserva sus criterios de aceptación junto al código al que
afecta.

## Grupos

| Grupo | Objetivo |
|---|---|
| `02-migracion-llm-providers/` | Completar proveedores y protocolos LLM bajo el contrato normalizado de Keel. |
| `03-mejoras-desde-analisis-docstore/` | Corregir brechas de observabilidad y de cierre verificable descubiertas en el análisis de documentación. |
| `_borradores/i18n/` | Investigación I18N aún no estandarizada como tareas; no es reclamable. |

## Cómo se trabaja

1. Usar `list_roadmap_tasks` para ver las tareas disponibles y su estado.
2. Usar `claim_task` antes de empezar una tarea. Si no se puede reclamar,
   elegir otra disponible.
3. Al terminar, cambiar el frontmatter de la tarea a `estado: hecho` y usar
   `release_task`.

Cuando se cambie la estructura de esta carpeta, ejecutar
`check_roadmap_format` antes de cerrar el trabajo.
