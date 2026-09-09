# F5 — External MCP integrations

## What it is

An app-level registry of EXTERNAL MCP servers (gmail, drive, github, …) in the
`mcp_servers` module, assignable PER AGENT from its profile — each agent's
configuration shows explicitly which integrations it carries
(`AgentProfile.mcpServers`, chips on the form).

## Model

`McpServerConfig{name, transport stdio|http, command+args+env+secretEnv,
url+headers}` (LMDB prefix `mcpserver_`). The name is the server's key → tools
reach the agent as `mcp__<name>__*`.

Credentials: `secretEnv` maps an environment key to the NAME of a registered
secret (F4); the VALUE is resolved only when building the turn's mcp-config,
which travels as a temporary 0700 file (never inline in argv). `env` and
`headers` are for non-sensitive values only.

## Per-turn wiring

- 1:1: `AgentsViewModel.sendMessage` resolves the profile's servers and merges
  them into the `mcpServers` map alongside `keelai-actions` and `keel-tools`;
  `extraAllowedTools += mcp__<name>` (a server-level grant).
- Projects: `StationsViewModel._runTurn` performs the same merge per member.

## Keel AI

`register_mcp_server` (idempotent by name; credentials ONLY through
`secret_env`), `delete_mcp_server`, and `create_or_update_agent` gains
`mcp_server_names` (additive). The fallback `agente` block: the `mcps:` key.

## UI

The "MCP integrations" screen (hub icon on the rail): a list with transport and
destination, a form with fields conditional on transport, and a secrets picker
(env key = the secret's name; different mappings go through Keel AI).

The picker does not only pick: it loads the value of a pending secret, changes
it, or deletes it without leaving the form (F4, "Where the value is loaded"),
and warns before saving if the MCP would be left without the key. The list marks
"key missing" on MCPs with unresolved secrets.

**No literal env field.** The form used to have a "Non-sensitive environment
variables" textarea next to the Secrets section, and read on screen they were
two places for the same thing — the question was which of the two to use for the
API key. In the UI there is ONE environment path: Secrets. The `env` field still
exists in the model for `register_mcp_server` (an MCP may need a `NODE_ENV`),
and when saving from the form it is preserved as it was instead of being wiped.

**A "Give it to Keel AI" switch.** Registering an MCP does not enable it: an
agent only sees it if its profile carries it. Normal agents are assigned one
from their profile form, but the assistant's profile is hidden from that screen
(its systemPrompt belongs to the app and is re-synced on every launch) and
`create_or_update_agent` rejects the reserved handle — meaning Keel AI cannot
assign it to itself, by hand or by asking itself. The form's switch is the only
path: it writes the server's name into the reserved profile's `mcpServers`
(`AgentProfilesViewModel.setKeelAiMcpServer`), which is NOT re-synced, so the
grant persists. It applies to the following turn.

## Limit

Codex agents (F6) do not receive external MCPs in v1 (their config goes through
their own TOML).

## What was added later

This document describes the mechanism: how a server is registered and how it
reaches a turn. What came on top — the catalog of known integrations, pasting a
published configuration, actually testing the connection, and pulling a header's
token from a secret — is in [F28](28-integrations-catalog.md).

Two things here went stale and are worth reading with F28 alongside: the
transport can now also be `sse`, and a remote server is no longer limited to
plain-text headers.
