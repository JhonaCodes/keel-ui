---
estado: libre
titulo: ClaudeApi(secretRef) — reader SSE propio
---

# ClaudeApi(secretRef) — reader SSE propio

## Qué hay que hacer

Agregar `ClaudeApi extends ClaudeTarget` (Anthropic Messages API) y
`ClaudeApiRunner`. @claude-llm-exp confirmó el protocolo pero dejó explícito
que esto **no es un ajuste menor** sobre `ClaudeCliRunner`:

- **Tools no traducen 1:1.** `kAlwaysAllowedTools`/`extraAllowedTools`
  restringen tools *built-in del CLI* (Bash/Read/Edit corridas por el
  proceso `claude`) — la Messages API no las tiene. Si `ClaudeApiRunner`
  necesita tool-use, hay que definir JSON Schema por tool en `tools:` **y**
  implementar el loop `tool_use → ejecutar → tool_result` del lado de Keel.
  Si el turno no necesita tools, `tools:` se omite y el problema no existe.
- **El parseo SSE no reusa `ClaudeStreamReader`.** Ese parsea NDJSON de
  `--output-format stream-json` (una línea = un evento ya normalizado). La
  Messages API emite SSE con eventos tipados y fragmentados
  (`message_start`, `content_block_start`, `content_block_delta` con
  `text_delta`/`input_json_delta`, `content_block_stop`, `message_delta`,
  `message_stop`) — el texto y el JSON de un tool call llegan troceados y
  hay que ensamblarlos. Necesita su propio `claude_stream_parser.dart` (ya
  previsto en la estructura de carpetas de `arquitectura-llm-providers`).

Decisión a tomar antes de escribir código: **¿el alcance inicial de
`ClaudeApiRunner` incluye tool-use, o arranca solo con turnos de texto
plano?** Cambia bastante el tamaño de la tarea — documentarla, no asumirla.

## Bloqueantes

Ninguno — el fix de cancelación del patrón `LlmRunner` compartido ya cerró
en GO antes de esta sesión, así que el patrón base a heredar está estable.

## Criterio de aceptación

- [ ] Decisión de alcance (tool-use sí/no en v1) documentada como comentario
      en `claude_api_runner.dart`.
- [ ] `claude_stream_parser.dart` converge al mismo `LlmEvent` que hoy
      produce `ClaudeStreamReader` desde el CLI (mismo contrato de salida,
      invariante 4 de `invariantes-llm-providers`).
- [ ] `secretRef` resuelto por header HTTP armado en el momento del
      request, nunca en claro ni logueado (invariante 3).
- [ ] Test a nivel `.run()` desde el arranque, incluyendo el camino de
      cancelación (mismo estándar que el fix de la CLI).
- [ ] Rama nueva en `llm_dispatcher.dart`.
