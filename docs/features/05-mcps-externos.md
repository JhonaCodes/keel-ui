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

El picker no solo elige: carga el valor de un secret pendiente, lo cambia o
lo elimina sin salir del formulario (F4, "Dónde se carga el valor"), y avisa
antes de guardar si el MCP quedaría sin la clave. La lista marca "falta la
clave" en los MCPs con secrets sin resolver.

**Sin campo de env literal.** El formulario tenía un textarea "Variables de
entorno NO sensibles" al lado de la sección Secrets, y leído en la pantalla
eran dos lugares para lo mismo — la pregunta era cuál de los dos usar para
la API key. En la UI hay UNA sola vía de entorno: Secrets. El campo `env`
sigue existiendo en el modelo para `register_mcp_server` (un MCP puede
necesitar un `NODE_ENV`), y al guardar desde el formulario se conserva tal
cual estaba en vez de borrarse.

**Switch "Dárselo a Keel AI".** Registrar un MCP no lo habilita: un agente
solo lo ve si su perfil lo lleva. A los agentes normales se les asigna
desde su formulario de perfil, pero el perfil del asistente está oculto de
esa pantalla (su systemPrompt es de la app y se re-sincroniza en cada
arranque) y `create_or_update_agent` rechaza el handle reservado — o sea
que Keel AI no puede asignárselo ni a mano ni pidiéndoselo a sí mismo. El
switch del formulario es la única vía: escribe el nombre del server en
`mcpServers` del perfil reservado
(`AgentProfilesViewModel.setKeelAiMcpServer`), que NO se re-sincroniza, así
que el grant persiste. Aplica al turno siguiente.

## Límite

Los agentes codex (F6) no reciben MCPs externos en v1 (su config va por
TOML propio).
