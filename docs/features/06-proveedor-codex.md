# F6 — Proveedor codex por agente

## Qué es

Cada perfil/agente declara su **proveedor** (`AgentProvider`): `claude`
(default) o `codex`. El badge de dos letras junto al nombre del agente (CL
naranja / CX verde, sin trademarks) dice cuál CLI lo corre. Se elige en el
formulario del perfil (dropdown Proveedor) y Keel AI lo setea con
`create_or_update_agent(provider: "codex")`.

## Adaptador (`core/services/codex_cli_service.dart`)

Emite el MISMO stream de eventos (`ClaudeEvent`) que el adaptador claude —
los consumidores (chat 1:1, estaciones) son agnósticos del proveedor.

Verificado contra `codex-cli 0.142.3` con una corrida real:

- `codex exec --json` emite JSONL de la familia `thread.started` /
  `turn.started|completed|failed` / `item.*` / `error`. `thread_id` es el
  session id; resume: `codex exec resume <id> --json`.
- **codex lee stdin cuando no es TTY** ("Reading additional input from
  stdin…") — el adaptador cierra `process.stdin` inmediatamente o el
  proceso espera EOF para siempre.
- codex sale con código 0 incluso en errores in-band (`{"type":"error"}`)
  — el parser los convierte en fallo visible.
- Sin flag de system prompt → el prompt del perfil viaja como preámbulo
  delimitado del PRIMER turno; los resumidos lo conservan del historial.
- Sandbox: acceso total → `danger-full-access`, si no `workspace-write`.

## Límites v1 (a propósito)

- Sin tools deterministas, sin MCPs (externos ni keelai-actions), sin
  esfuerzo: esas superficies no existen en el adaptador. El formulario lo
  avisa.
- El selector de modelo del chat se ignora para codex (usa el modelo de su
  propia config TOML).
- El costo por turno se reporta 0 (codex no lo emite en el JSONL).

## Estaciones

`TaskRunSpec.provider` viaja al isolate, que elige ejecutable, argumentos y
dialecto de parseo (`_parseCodexEventToMessages`, espejo del servicio — el
isolate es auto-contenido por diseño).
