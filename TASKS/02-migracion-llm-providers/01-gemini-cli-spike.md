---
estado: libre
titulo: Gemini Cli — spike de diseño (hooks/MCP por-turno)
---

# Gemini Cli — spike de diseño (hooks/MCP por-turno)

## Qué hay que hacer

Implementar `GeminiTarget { GeminiCli }` y `GeminiCliRunner`, siguiendo el
patrón de `ClaudeCliRunner`/`CodexCliRunner` — pero antes de escribir el
runner, resolver un punto de diseño que @gemini-llm-exp dejó explícito
durante el diseño de arquitectura: Gemini CLI no tiene equivalente a
`--settings` de Claude para inyectar hooks/MCP por-turno. Esa config vive en
`settings.json` **persistente** del proyecto, mutable por `gemini hooks
migrate` / `gemini mcp add`.

Protocolo ya cerrado (no investigar de nuevo):
- Streaming: `-o/--output-format stream-json`, formato array JSON.
- Auth: API-key estándar.
- System prompt: sin flag propio (`--system-prompt`/`--append-system-prompt`
  no existen) — mismo workaround que Codex, preámbulo delimitado en el
  prompt de usuario. Esto es implementación directa, no bloquea.
- Permisos: `--approval-mode {default,auto_edit,yolo,plan}` y
  `--policy`/`--admin-policy` sí son inyectables por-turno vía flags, sin
  problema.

Decisión a tomar acá (esto es lo que hace spike a esta tarea):

- **Opción A** — `GeminiCliRunner` v1 corre sin hooks/MCP por-turno
  (governance obligatoria de audit-gate/tdd-manda no aplica a turnos
  Gemini), igual que la primera versión que se aceptó para OpenCode Cli.
- **Opción B** — resolver un lock sobre el `settings.json` real del proyecto
  para poder aislar hooks/MCP entre turnos concurrentes, análogo a lo que
  `CliTurnWorkspace` hace con un archivo temporal 0700 para Claude/Codex.

## Bloqueantes

Ninguno.

## Criterio de aceptación

- [ ] Decisión A o B tomada y documentada como comentario en
      `gemini_cli_runner.dart` (no implícita).
- [ ] `GeminiTarget`/`GeminiCliRunner`/reader implementados con test a nivel
      `.run()` desde el arranque (no como deuda pendiente — mismo estándar
      que se exigió para el fix de cancelación de Claude/Codex Cli).
- [ ] Rama nueva en `llm_dispatcher.dart`, sin tocar el `switch` existente
      de Claude/Codex.
- [ ] Si se eligió la opción A, el gap de governance-por-turno queda
      marcado con `keel-debt:` en el código, no silencioso.
