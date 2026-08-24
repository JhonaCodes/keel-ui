# Migración de proveedores LLM — targets pendientes tras el diseño del sealed

Cuando todo esto esté hecho, `LlmProvider`/`llm_dispatcher.dart` cubren
Gemini, Qwen, Claude API y Codex API con el mismo patrón que hoy tienen
Claude CLI y Codex CLI — sin `default` en el dispatcher, sin secrets en
claro, con su propio reader normalizando a `LlmEvent` (ver
`arquitectura-llm-providers` e `invariantes-llm-providers`).

No incluye `OpenAiCompatibleApiRunner` (DeepSeek/MiniMax/OpenRouter): ese es
trabajo activo de la sesión que abrió esta carpeta, ya en el plan de esa
sesión — no un pendiente de roadmap.

## Carpetas

El número manda el orden en que hay que tomarlas — es el orden de spike de
mayor incertidumbre primero, cerrado con los 6 expertos de proveedor
consultados en paralelo durante el diseño.

| Tarea | Qué cubre | Estado |
|---|---|---|
| `01-gemini-cli-spike.md` | Resolver aislamiento de hooks/MCP por-turno sin `--settings` | libre |
| `02-qwen-cli-spike.md` | Verificar schema de stream + flag de system prompt (fork de Gemini CLI) | bloqueada por 01 |
| `03-claude-api-runner.md` | `ClaudeApi(secretRef)` — reader SSE propio, decisión de alcance tool-use | libre |
| `04-codex-api-runner.md` | `CodexApi(secretRef)` — reader SSE propio, decisión de alcance tool-use | libre |
| `05-codex-resume-flags-fix.md` | Bug: `codex exec resume` rechaza `-s`/`-p`/`--color` | libre |
| `06-opencode-cli-protocol.md` | Protocolo CLI y traducción fail-closed de permisos | hecho |

## Cómo se trabaja acá

1. `list_roadmap_tasks` para ver qué hay y qué está tomado.
2. `claim_task` sobre la que vayas a hacer. Si falla, otro se te adelantó:
   pasá a la siguiente, no insistas.
3. Al terminar: `estado: hecho` en el archivo de la tarea, y `release_task`.

Si tocaste la estructura de esta carpeta, `check_roadmap_format` antes de
cerrar.
