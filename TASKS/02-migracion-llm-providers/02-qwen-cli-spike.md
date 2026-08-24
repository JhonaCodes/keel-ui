---
estado: libre
titulo: Qwen Cli — spike de protocolo (fork de Gemini)
---

# Qwen Cli — spike de protocolo (fork de Gemini)

## Qué hay que hacer

Implementar `QwenTarget { QwenCli }` y `QwenCliRunner`. Qwen Code es un fork
del código de Gemini CLI — @qwen-llm-expert confirmó que comparte su familia
de eventos de streaming, no la de Claude/Codex. Por eso este spike se reduce
a diffear contra lo que ya salió de `01-gemini-cli-spike.md`, no a investigar
desde cero.

Flags de superficie ya confirmados por docs (no investigar de nuevo):
`--output-format json|stream-json`, `--resume`, `--continue`.

Sin confirmar todavía (correr `verificar-flags-cli qwen` contra el binario
real antes de implementar):
- Schema exacto de cada evento del stream — puede diferir de Gemini aunque
  comparta familia.
- Flag de system prompt — razonable esperar que herede la misma limitación
  (o solución) que Gemini, pero no asumirlo sin verificar.

Nota de diseño ya resuelta, no repetir el análisis: `QwenApi` **no** necesita
runner propio — DashScope (la API de Qwen) es OpenAI-compatible (Bearer
token, shape de Chat Completions), así que `Qwen(OpenAiCompatible(baseUrl:
'<dashscope>', ...))` alcanza reusando el runner compartido que ya existe
para DeepSeek/MiniMax/OpenRouter, salvo que aparezca necesidad real de la
Responses API con estado del lado del servidor de DashScope.

## Bloqueantes

- [ ] 02-migracion-llm-providers/01-gemini-cli-spike.md — el mapeo de
      hooks/MCP y el patrón de reader que resuelva Gemini aplica igual acá;
      hacer este spike antes es investigar dos veces lo mismo.

## Criterio de aceptación

- [ ] `verificar-flags-cli qwen` corrido contra el binario real, con
      evidencia (no documentación) del schema de streaming y del flag de
      system prompt.
- [ ] `QwenTarget`/`QwenCliRunner`/reader implementados con test a nivel
      `.run()` desde el arranque.
- [ ] Rama nueva en `llm_dispatcher.dart`.
- [ ] Confirmado (o descartado con evidencia) que `QwenApi` no necesita
      clase propia.
