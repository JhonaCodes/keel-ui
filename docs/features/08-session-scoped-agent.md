# F8 — Session-scoped agent

## What it is

A project session can add agents FOR THAT SESSION ONLY
(`StationTask.extraProfileIds`), without touching the project roster: other
sessions do not see them, they do not show up as companions in their prompts,
and mentions of them do not resolve there. To have an agent in EVERY session you
modify the project (form or Keel AI), as always.

## Mechanics

- `membersOf(Station, {StationTask? task})` = the project's members ∪ the
  session's extras. EVERY turn site passes the session through: per-step role
  resolution, follow-up owner, `@handle` consultations, the companions prompt,
  resumption after a permission, `askAboutLine`, and `recordManualEdit`.
- The ```agente declarations a member makes mid-conversation now add to the TASK
  (previously: to the project) — the global profile is still registered and
  reusable, but membership stays scoped to that conversation. The thread message
  says so: "added @x to THIS session".
- VM: `addAgentToTask` / `removeAgentFromTask` (extras only; project members are
  not removed from here).

## UI

A person+ button in the session header opens the "Agents in this session" panel
with three sections: project members (read-only), session extras (with a remove
action), and registered agents available to add.
