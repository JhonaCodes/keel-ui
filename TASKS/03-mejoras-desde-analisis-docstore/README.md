# Mejoras a partir del análisis Keel vs. "The Closed Loop" / "The Working-Doc Spine"

Estas tres tareas salen de un análisis comparativo evidencia-basada: un workflow leyó
completos dos documentos de arquitectura externos sobre un store de trabajo en
markdown+git (captura, integridad, disposición), identificó qué de eso Keel no tiene,
y después investigó el código REAL de este repo — no supuestos, no la spec — para
confirmar cada brecha con cita archivo:línea, más una segunda pasada adversarial que
intentó refutar esas citas antes de darlas por buenas.

El informe completo (contexto de los dos documentos, comparación mecanismo por
mecanismo, qué de ahí NO vale la pena copiar y por qué) vive en
`/Users/jhonacode/keel-projects/doc-analysis/INFORME-keel-vs-closed-loop.md`. Estas
tareas son solo la parte accionable, ya verificada contra este repo.

## Carpetas

| Tarea | Qué cubre | Esfuerzo | Estado |
|---|---|---|---|
| `01-vault-detectar-no-corrio.md` | El vault reporta "corrió y falló" pero no "debía correr y no corrió" | bajo | libre |
| `02-cerrar-sesion-contra-pr-real.md` | Una sesión puede cerrar `finished` sin que exista un PR real | medio | libre |
| `03-lastused-y-reapertura-skills.md` | Skills sugeridas sin señal de uso ni reapertura entre proyectos | medio | libre |

El orden es por costo/beneficio (la más barata y más urgente primero), no por
dependencia — las tres son independientes entre sí y se pueden tomar en cualquier
orden.

## Cómo se trabaja acá

1. `list_roadmap_tasks` para ver qué hay y qué está tomado.
2. `claim_task` sobre la que vayas a hacer. Si falla, otro se te adelantó: pasá a la
   siguiente, no insistas.
3. Al terminar: `estado: hecho` en el archivo de la tarea, y `release_task`.

Si tocaste la estructura de esta carpeta, `check_roadmap_format` antes de cerrar.

## Nota sobre evidencia

`02` y `03` pasaron una auditoría adversarial de citas — un segundo agente reabrió
cada archivo:línea citado intentando refutarlo. Resultado en las dos: `citations_verified:
true`, confianza alta, cero correcciones.

`01` no pasó esa segunda pasada: el agente de verificación se cortó por límite de
sesión antes de correr (`You've hit your session limit`). Sus citas vienen de un solo
agente con rastro de búsqueda explícito, y las dos más load-bearing (el comentario de
`system_vault_viewmodel.dart` y la frase "the scheduling itself lives outside the app"
de `jobs_api.dart`) las reabrí y confirmé a mano antes de escribir la tarea. El resto
de las citas de `01` no tuvo esa segunda mirada — quien la tome debería reconfirmarlas
antes de escribir código sobre ellas.
