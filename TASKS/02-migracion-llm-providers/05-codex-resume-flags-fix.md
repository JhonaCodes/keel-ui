---
estado: libre
titulo: codex exec resume rompe con -s/-p/--color
---

# codex exec resume rompe con -s/-p/--color

## Qué hay que hacer

Bug reportado en producción: `error: unexpected argument '-s' found` al usar
codex en un agente que retoma sesión (resume). Causa raíz confirmada
corriendo el binario real (`codex exec resume --help` vs `codex exec
--help`):

`buildCodexArguments` (`lib/src/integrations/llm/codex/codex_arguments.dart:38-50`)
arma siempre `[exec, resume, <id>, ..., -s, <modo>, ..., -p, <perfil>,
--color, never, ...]` cuando hay `sessionId`. Pero `codex exec resume` es un
**subcomando** con su propio parser clap, y ese parser **no define**
`-s/--sandbox`, `-p/--profile` ni `--color` — esos tres flags solo existen en
`codex exec` (el padre). Confirmado por ausencia explícita en el listado
completo de `codex exec resume --help` (sí tiene `-c`, `--last`, `--all`,
`--enable/--disable`, `-i`, `--strict-config`, `-m`, `--dangerously-*`,
`--skip-git-repo-check`, `--ephemeral`, `--ignore-*`, `--output-schema`,
`--json`, `-o`).

@codex-llm-expert confirmó que su skill `codex-llm-protocolo` no trae
evidencia línea por línea de si el sandbox/perfil se preservan en resume o
se resetean — su hipótesis (que el sandbox es un flag por-proceso, no un
estado persistido del lado del servidor) es inferencia de diseño, no dato
verificado.

**Decisión de diseño a tomar antes de escribir el fix** (documentarla, no
asumirla): ¿`-s`/`-p`/`--color` se omiten sin más en la rama resume, o el
sandbox/perfil se preserva pasando `-c sandbox_mode=...`/`-c` (config
override, sí soportado por `resume` según su `--help`)? Verificar contra el
binario real, no contra memoria del protocolo.

## Bloqueantes

Ninguno — el fix de cancelación del patrón `LlmRunner` compartido ya cerró
en GO antes de esta sesión.

## Criterio de aceptación

- [ ] Decisión de diseño (qué pasa con `-s`/`-p`/`--color` en resume)
      documentada como comentario en `codex_arguments.dart`.
- [ ] `buildCodexArguments` no emite ningún flag que `codex exec resume`
      rechace — verificado corriendo el binario real, no solo por lectura
      de `--help`.
- [ ] Test nuevo en `codex_arguments_test.dart` que verifique el **argv
      completo** esperado para la rama resume (hoy solo chequea
      `args.sublist(0, 3)`, por eso el bug no se detectó).
- [ ] Regresión: la rama sin resume (turno nuevo) sigue igual.
