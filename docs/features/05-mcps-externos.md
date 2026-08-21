# F5 — Integraciones MCP externas

## Qué es

Registro a nivel app de servidores MCP EXTERNOS (gmail, drive, github, …)
en el módulo `mcp_servers`, asignables POR AGENTE desde su perfil — la
configuración de cada agente muestra explícitamente qué integraciones lleva
(`AgentProfile.mcpServers`, chips en el formulario).

## Modelo

`McpServerConfig{name, transport stdio|http, command+args+env+secretEnv,
url+headers}` (prefijo LMDB `mcpserver_`). El nombre es la clave del server
→ las tools llegan al agente como `mcp__<nombre>__*`.

Credenciales: `secretEnv` mapea una clave de entorno al NOMBRE de un secret
registrado (F4); el VALOR se resuelve recién al armar el mcp-config del
turno, que viaja como archivo temporal 0700 (nunca inline en argv).
`env`/`headers` son solo para valores no sensibles.

## Wiring por turno

- 1:1: `AgentsViewModel.sendMessage` resuelve los servers del perfil y los
  fusiona al mapa `mcpServers` junto con `keelai-actions` y `keel-tools`;
  `extraAllowedTools += mcp__<nombre>` (grant a nivel server).
- Estaciones: `StationsViewModel._runTurn` hace el mismo merge por miembro.

## Keel AI

`register_mcp_server` (idempotente por nombre; credenciales SOLO por
`secret_env`), `delete_mcp_server`, y `create_or_update_agent` gana
`mcp_server_names` (aditivo). Bloque `agente` de resguardo: clave `mcps:`.

## UI

Pantalla "Integraciones MCP" (icono hub en el rail): lista con transporte y
destino, formulario con campos condicionales por transporte y picker de
secrets (clave env = nombre del secret; mapeos distintos vía keelai).

## Límite

Los agentes codex (F6) no reciben MCPs externos en v1 (su config va por
TOML propio).
