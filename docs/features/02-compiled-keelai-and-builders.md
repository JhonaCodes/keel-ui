# F2 — Compiled Keel AI + builder agents

## What it is

1. **Compiled knowledge**: Keel AI's system prompt AND its system-map skill
   (`keelai-mapa-del-sistema`) are synced with the code's constants on EVERY
   launch (`seedKeelAi` → `syncReservedProfilePrompt` +
   `SkillsViewModel.syncReservedSkillContent`). The map used to be seeded once
   and went stale on existing installs; now editing that skill by hand is lost
   on the next launch — it is the app's knowledge, not the user's.
2. **A complete project interview**: the seed instructs Keel AI to build a
   project by interviewing ONE question at a time (purpose → verified folder →
   members/roles → workflow → tools → rules) and to run every creation in
   dependency order in a single response.
3. **Builder agents** (`AgentProfile.canManageSystem`): a profile marked as a
   builder receives the full `keelai-actions` MCP in its 1:1 chats — it can
   create skills, rules, tools, agents, workflows, and projects just like Keel
   AI. The check is live per turn (`AgentsViewModel._canManageSystem`), so
   revoking the switch applies to the following turn.

## How it is granted

- UI: the "Can manage the system" switch on the registered-agent form.
- Keel AI: `create_or_update_agent` accepts `system_builder: bool` (nullable on
  update: if absent, the previous value is kept). The trace line in the thread
  makes the grant visible.

## Limits

- The fenced-block CREATION fallback (```skill, ```regla, ```workflow,
  ```proyecto) belongs to Keel AI — builders act through real MCP tools. Note:
  it is NOT the system's only fenced dialect. A project member declares
  specialists with its own ```agente block (4 keys: handle/rol/proposito/
  instrucciones, see F8), and a codex member writes the plan with
  ```plan/```cumplido (see F6/F17). These are different parsers with different
  keys.
- `canManageSystem` does not travel to an export without review (see F21): on
  import, whatever the JSON says is honored, and the user reviews it.
