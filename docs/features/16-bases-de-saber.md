# F16 — Bases de saber

Reemplaza a **F11 (Sección Conocimiento)**: una sola carpeta global,
indexada plana y sin vínculo con nada. Su punto de entrega a los agentes
(`KnowledgeViewModel.mirrorPathIfPresentSync`) se asignaba y no lo leía
nadie, así que ningún agente sabía que el saber existía.

## Qué es

El saber deja de ser una carpeta y pasa a ser un catálogo de **bases**, cada
una con nombre propio y frontera de contexto: `NUI`, `CONNECT`, `KIWIO`.
Un proyecto ve las suyas y ninguna más.

## El modelo

`KnowledgeBase`: nombre único, descripción de una línea (*qué contesta esta
base*) y una fuente.

| Fuente | Dónde vive | Sincronizar |
|---|---|---|
| `git` (url + rama) | `AppSupport/knowledge/<nombre>/` | clone / `pull --ff-only` |
| `local` (ruta en disco) | la carpeta misma, sin copiar | nada que sincronizar |

Módulo de catálogo completo (modelo + repositorio con prefijo
`knowledgebase_` + ViewModel), como skills o reglas: por eso entra sola al
export y al `list_catalog`.

## La frontera

- `Station.knowledgeBaseNames` — por nombre, igual que `ruleNames`.
- `AgentProfile.knowledgeBaseNames` — el caso **oráculo**: un agente cuyo
  trabajo es contestar desde una base, usable en 1:1 fuera de toda proyecto.
  Es una excepción deliberada al aislamiento — esa base viaja con él.

`Station.documentPaths` **desaparece**: un documento suelto es una base
local apuntando a su carpeta. Dos mecanismos para "acá consultás" era la
redundancia que costaba dos listas en cada turno.

## Lo que recibe un agente: el mapa, no el territorio

Por base vinculada, el turno recibe un resumen de tamaño fijo — no importa
si la base tiene 60 documentos o 6.000:

```
Base de saber "NUI" — contratos de API, dominio y procesos de NUI Markets.
Raíz: /Users/…/knowledge/NUI  (63 documentos)
  api/ (14) · dominio/ (9) · procesos/ (7) · release/ (3)
Buscá acá con Grep/Read cuando necesites un dato del proyecto.
```

Si la raíz tiene un `INDEX.md`, **su contenido se inyecta** (con tope de
tamaño). Ese archivo lo escribe el usuario y es la portada: es lo que
convierte "sabe dónde consultar" en "sabe qué consultar".

No hace falta una tool MCP para leer: leer y buscar archivos ya está
siempre permitido (`kAlwaysAllowedTools`), así que funciona igual con
`claude` y con `codex`. El mismo resumen lo arma una sola función,
consumida por `_turnSystemPrompt` (proyectos) y por
`_resolveProfileSystemPrompt` (1:1).

## La pantalla

Árbol a la izquierda: bases en la raíz, carpetas desplegables, archivos como
hojas, leído del disco en vivo. Visor a la derecha, por extensión, con
paquetes que ya están en el pubspec:

| Qué | Con qué |
|---|---|
| `.md` | el renderer del chat **con su `codeBuilder`**: los bloques ```mermaid``` y ```svg``` se dibujan como diagramas |
| `.svg` | `flutter_svg` |
| imágenes | `Image.file` |
| código y texto | `flutter_highlight` |
| el resto | tarjeta con "abrir con la app del sistema" |

Lucidchart es un servicio web, no un archivo: no hay nada que renderizar
dentro de la app. Lo que funciona es exportar el diagrama a `.svg`/`.png`
dentro de la base, o dejar un `.md` con el link. Mermaid es nativo y vive
versionado en texto.

## Sincronizar

Botón por base y "actualizar todas" en la pantalla. `sync_knowledge(base)`
como tool de Keel AI, para pedirlo hablando. Nada corre en background.

## Lo que puede hacer Keel AI

| Tool | Para qué |
|---|---|
| `create_knowledge_base` | Registra la base. Con `source: "local"` **crea la carpeta si no existe** — es el camino para que un agente arme una base y escriba adentro. Desde el formulario la validación sigue siendo estricta: ahí una ruta inexistente es un error de tipeo. |
| `update_knowledge_base` | Nombre, descripción o fuente. Solo lo que manda. |
| `delete_knowledge_base` | Saca el registro. **No borra los documentos del disco.** |
| `sync_knowledge(base?)` | Pull + reindexado; sin `base`, todas. |
| `list_catalog(kind: "knowledge_bases")` | Nombre, cantidad de documentos y descripción. |
| `get_item(kind: "knowledge_base")` | Raíz en disco, tamaño, problemas y qué proyectos la usan. |
| `update_station(knowledge_base_names)` | Se la da a un proyecto. La lista reemplaza a la actual. |
| `create_or_update_agent(knowledge_base_names)` | El caso oráculo. |

El contenido lo escribe el agente con sus propias herramientas de archivo
dentro de la raíz de una base local: no hay tool para escribir documentos,
porque `Write` ya existe y una tool paralela solo agregaría una forma más de
hacer lo mismo. En una base `git` el espejo no se escribe — lo que se
escriba ahí se pierde en el próximo pull; los cambios van al repo.

## Qué viaja en el export

Dos niveles, y el segundo se elige por base:

1. **La definición** — nombre, descripción, fuente git (url + rama), y qué
   proyectos y perfiles la usan, por nombre. Chica, siempre va.
2. **El contenido** — los documentos mismos, embebidos en el archivo de
   respaldo. Opcional por base, porque no todas lo necesitan:
   - una base `git` se recupera clonando, así que su contenido es
     redundante;
   - una base `local` **existe únicamente en este disco**: sin su contenido,
     el respaldo no respalda nada.

Las rutas nunca viajan (misma convención que el `workingDirectory` de una
proyecto). Al importar:

- si el contenido vino en el archivo y la base no tiene una carpeta con
  documentos, se restaura en `AppSupport/knowledge/<nombre>/` y la base
  queda apuntando ahí;
- si la base ya tiene documentos en disco, el contenido embebido **no se
  escribe**: importar nunca pisa lo que ya está.

El panel de export muestra las bases una por una con su tamaño estimado,
para que incluir el contenido sea una decisión informada y no una sorpresa
de 800 MB.

## Migración desde F11

`settings.knowledgeRepoUrl` se lee **una sola vez**: si no hay ninguna base
registrada y esa URL no está vacía, se crea la base `conocimiento` con ella
y el campo queda en blanco. La sección "Conocimiento" sale de Configuración
en el mismo movimiento.
