---
estado: libre
titulo: CodexApi(secretRef) — reader SSE propio
---

# CodexApi(secretRef) — reader SSE propio

## Qué hay que hacer

Agregar `CodexApi extends CodexTarget` y `CodexApiRunner`.
@codex-llm-expert confirmó el protocolo:

- **`/v1/responses`, no `/v1/chat/completions`** — es el reemplazo
  agéntico-con-estado que corresponde acá.
- **Resume**: `previous_response_id` en el body reemplaza a
  `resume <sessionId>` del CLI — mapear `spec.sessionId` directo a ese
  campo, no inventar manejo de historial paralelo.
- **System prompt**: `instructions` top-level del request, o primer item de
  `input` con `role: "system"` — confirmar el shape exacto contra la doc
  vigente al implementar, la Responses API cambió esto más de una vez.
- **Streaming necesita reader propio**, mismo motivo que Claude API:
  `CodexStreamReader` parsea NDJSON de `codex exec --json`; la Responses API
  expone SSE tipado (`response.output_text.delta`, `response.completed`,
  etc.) — shape y semántica distintos. Se necesita
  `codex_api_stream_reader.dart` (estructura de carpetas: junto a
  `codex_api_runner.dart`, análogo a `claude_stream_parser.dart`).
- **Tools**: `-s workspace-write` (sandbox del CLI) no es lo mismo que un
  allowlist — si `CodexApiRunner` v1 incluye tool-calling, el mapeo de
  permisos no es 1:1 con el CLI. Mismo tipo de decisión que Claude API.

## Bloqueantes

Ninguno.

## Criterio de aceptación

- [ ] Decisión de alcance (tool-use sí/no en v1) documentada.
- [ ] `codex_api_stream_reader.dart` converge al mismo `LlmEvent` que hoy
      produce `CodexStreamReader` desde el CLI.
- [ ] `previous_response_id` mapeado desde `spec.sessionId`, sin lógica de
      historial paralela.
- [ ] `secretRef` resuelto por header HTTP en el momento del request.
- [ ] Test a nivel `.run()` desde el arranque, incluyendo cancelación.
- [ ] Rama nueva en `llm_dispatcher.dart`.
