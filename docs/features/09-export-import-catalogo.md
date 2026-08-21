# F9 — Export/import de catálogo a repo git

## Qué es

Todo el catálogo (skills, reglas, tools, workflows, MCPs externos, agentes
registrados y estaciones) viaja a un repo git configurado por UI
(Configuración → Sincronización), como JSON portable **por nombre**, y se
importa en otra máquina con un merge idempotente.

## Formato (`catalog/<categoría>/<nombre>.json` en el repo)

- Referencias por NOMBRE, nunca por id: perfiles refieren skills/reglas/
  tools/MCPs por nombre; estaciones refieren agentes por handle y workflows
  por nombre.
- **Nunca viaja**: secrets (ni sus valores ni el catálogo — solo las
  referencias que tools/MCPs ya llevan), `workingDirectory`,
  `documentPaths`, tareas/hilos, ids. La skill de mapa de Keel AI tampoco
  (es conocimiento compilado re-sembrado en cada arranque).
- El directorio `catalog/` se regenera completo en cada export, así los
  borrados también se propagan.

## Flujo

- **Exportar**: clone-or-pull del repo al mirror local
  (`AppSupport/catalog_sync/repo`) → escribir catálogo → `git add/commit/
  push`. "nothing to commit" no es error.
- **Refresh (importar)**: pull → merge por nombre (crea lo que falta,
  actualiza lo existente) en orden de dependencia: skills → reglas → tools
  → workflows → MCPs → perfiles → estaciones. Estaciones nuevas quedan sin
  carpeta: el canal muestra un banner "Elegir carpeta" (`getDirectoryPath`)
  hasta que el usuario la selecciona — las rutas se piden, jamás se
  inventan.

## Piezas

- `integrations/catalog_sync/` — `CatalogSyncViewModel` (busy/log/lastSync)
  + serializador y merger (`src/catalog_files.dart`) + git por `Process`.
- Settings: `AppSettings.catalogRepoUrl` + sección Sincronización con
  botones Exportar/Refresh y log del último resultado.
- Keel AI: `export_catalog()` / `refresh_catalog()`.

## Requisitos de entorno

`git` instalado y con credenciales para el repo (SSH o HTTPS con helper).
Los commits usan la identidad git global del usuario.
