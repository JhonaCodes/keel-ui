# F11 — Sección Conocimiento

## Qué es

Documentación markdown descargada de un repo git configurable POR UI
(Configuración → Conocimiento → URL), navegable dentro de la app (icono
libro en el rail).

## Mecánica

- `KnowledgeViewModel.update()`: clone `--depth 1` o `git pull --ff-only`
  a `Application Support/knowledge/repo`, reindexa todos los `.md`
  (recursivo, excluye `.git/`).
- Pantalla: lista filtrable por nombre (con su carpeta como subtítulo) +
  visor `GptMarkdown` (el mismo renderer del chat) con selección de texto.
- Botón **Actualizar** en la pantalla; Keel AI también puede dispararlo con
  `update_knowledge`.
- Los agentes pueden LEER los documentos con sus herramientas de archivo —
  el seed de Keel AI les cuenta dónde viven.

## Contenido inicial

Decisión del usuario (la URL es 100% configurable). Candidato natural: un
subset curado de la documentación del workspace NUI (393 .md en
`nui-workspace/docs`, markdown plano — compatible sin conversión).
