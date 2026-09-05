# F51 — Codex con la misma superficie que claude

## Problema que resuelve

Un nodo con dueño codex corría a ciegas. No recibía ningún servidor MCP (ni
el plan, ni `ask_user`, ni los requerimientos), su identidad viajaba envuelta
en el prompt del usuario y se repetía en cada resume, no tenía tope de turnos
(codex no tiene `--max-turns`), y con codex 0.153 los hooks que Keel le pasaba
—el gate de permisos incluido— **no corrían y nadie se enteraba**: el binario
exige «trust» persistente para cada hook, y los de Keel se generan por turno.
Además `exec resume` dejó de aceptar `-p <perfil>` y rechaza `-c profile=`
como legacy, así que el perfil TOML por turno no cubría más que el primer
turno de cada sesión. Encima, el binario instalado (0.149) rechazaba el modelo
por defecto de la config del usuario: todo turno codex fallaba con 400.

## Decisión

Todo lo configurable de un turno de codex viaja por `-c clave=valor`, que es
lo único que `exec` y `exec resume` aceptan por igual (verificado contra codex
0.153.4 el 2026-09-05, capturando los requests con un proveedor falso):

- **Instrucciones de rol** → `-c developer_instructions="..."` solo en el
  primer turno. Codex las persiste en el hilo como mensaje de desarrollador y
  las reenvía en cada resume; mandarlas de nuevo era pagarlas dos veces. El
  prompt del usuario queda limpio (`buildCodexPrompt`: pedido + modo plan).
- **Hooks** → `-c hooks.<Evento>=[...]`, un override por evento
  (`renderCodexOverrides`), más `--dangerously-bypass-hook-trust` cuando hay
  alguno. Sin ese flag codex ignora el hook en silencio; con él corre y el
  contrato es el mismo de claude (`tool_name: "Bash"`, `permissionDecision`).
  El gate de permisos (F45) ahora cubre exec **y** resume.
- **MCP** → `-c mcp_servers.<nombre>.url=...` para HTTP, `command`/`args`
  para stdio (`codexMcpConfig`, sobre el mismo `mcp.json` que recibe claude).
  Los secrets nunca van en argv: los headers van por `env_http_headers`
  apuntando a variables del entorno del proceso, y el `env` de un stdio se
  reenvía por `env_vars` (los hijos de codex no heredan el entorno). Con esto
  un nodo codex tiene plan, decisiones, roadmap, requerimientos, tableros y
  las tools del usuario, igual que claude. El espejo por bloques ```plan que
  existía para codex se borró: ya tiene las tools.
- **Tope de turnos** → hook `keel-tool-cap`: cuenta llamadas a herramientas
  y deniega la que excede `maxTurns × 3` (`kCodexToolCallsPerTurn`) con un
  motivo que pide cerrar con `keel-outcome`. El preflight lo dice.
- **Binario** → actualizado a 0.153.4 (`npm i -g @openai/codex`); el modelo
  por defecto vuelve a funcionar.

`CliTurnWorkspace` ya no escribe perfiles en `$CODEX_HOME`; solo los wrappers
de hooks, y devuelve los overrides con la ruta real.

## Lo que sigue distinto

- Codex no informa costo: el techo de costo por sesión no lo frena. Sí lo
  frenan el tope de herramientas, el vigilante y el techo de tokens del hilo.
- El cupo de subagentes (F47) sigue siendo de claude: codex no tiene `Task`.
- La config global del usuario (`~/.codex/config.toml`: MCPs propios,
  plugins, skills) se carga en cada turno de Keel. Es del usuario y no se toca.

## Cómo verificarlo

- `test/llm/codex/codex_cli_runner_test.dart`: un `codex` falso vuelca argv y
  entorno; el gate viaja por `-c` con el flag de trust, el bearer del MCP está
  en el entorno y no en argv, `developer_instructions` va solo en exec.
- `test/llm/codex/codex_config_overrides_test.dart`: la traducción de
  `mcp.json` a overrides, HTTP y stdio, sin secrets en los overrides.
- `test/hooks/tool_cap_hook_test.dart`: el script real deja pasar N y deniega
  la N+1 pidiendo el cierre.
- `test/hooks/decision_gate_hook_test.dart`: codex recibe el gate como
  override.
