# 10 — Differences from other tools

## The comparison axis

It's not a marketing feature table. The real axis is this: **how many projects and agents does the system coordinate at once, and what persists between sessions?**

Most code assistants today — whether a CLI you run in a terminal or an extension inside an IDE — are built around the same unit: **one person, one agent, one repo, at a time**. That includes tools the reader probably knows: Claude Code and Codex CLI as terminal CLIs, Cursor and Windsurf as IDE extensions with an agent built into the editor. Different categories on the surface (terminal vs. editor), but same architecture underneath.

Keel wraps exactly those same CLIs underneath — it doesn't compete with them on "how well does the model complete code", because **it's the same model, with the same login**. What it adds is the layer on top: coordination between multiple agents with fixed roles, across multiple projects, with reusable processes between them, and persistence of knowledge that survives any single session ([see root README](../../README.md)).

## The three levels of "multi-agent"

The word "multi-agent" covers three different things, and the difference that
matters lives there.

| Level | What it is | Who does it |
|---|---|---|
| **1 — Anonymous fan-out** | An agent opens internal subagents inside its own turn. They don't exist outside that run, leave no reviewable trace, and answer to nobody registered. | Practically everyone |
| **2 — Scripted graph** | A DAG where each node has a role and the handoff is defined up front by whoever programmed the graph. | Frameworks (LangGraph, CrewAI, AutoGen) — libraries, not products |
| **3 — Consultation between registered peers** | An agent decides mid-turn that it needs another one, mentions it, and that fires a real turn of a registered identity that answers from its own specialty. | Keel |

Keel is not at level 3 *in addition to* level 1: it is at level 3 **instead
of** it. The CLI's anonymous subagent is **forbidden outright** — a
`PreToolUse` hook on `Task` denies the call, in code and not in the prompt
([F47](../features/47-subagent-quota-in-code.md)) — and the only path to
a specialist is declaring it and having the app register it in the open. What
remains allowed is a per-node quota, declared by the workflow, and **only for
research, impact inventory, or verification**: never for writing.

That inversion is the underlying design decision, and it buys three things a
fan-out cannot give even with more features bolted on:

- **Auditability.** Every consultation has an author, a recipient, attributable
  cost, and a node on the Map. An anonymous subagent leaves none of that.
- **Specialists that persist.** `@lumen-researcher` is the same agent with the same rules
  across every project, not an ephemeral prompt the parent invented for that
  run and lost on exit.
- **Real separation of powers.** The consulted agent cannot write: consulting
  is not delegating. That addresses the classic multi-agent failure mode, which
  is two writers stepping on the same file.

The mechanism itself is detailed in
[04 — Delegation and teams](04-delegation-and-teams.md).

## Comparison by architecture

| | One agent in terminal / IDE (general category) | Keel |
|---|---|---|
| **Unit of work** | One chat session with one agent, in one repo | One project with multiple member agents, with several sessions in parallel |
| **Agent identity** | Lives in the session; re-explained each time a new one opens | A registered profile once (handle, role, skills), reusable in all projects |
| **Coordination between agents** | Manual: the person copy-pastes context between terminal windows | An adaptive resolution graph with one owner, structured findings, and bounded consultations |
| **Communication between projects** | Doesn't exist as a concept — each terminal is an island | Internal requirements with verdict and explicit asymmetry of who closes |
| **What persists between sessions** | The history of that one conversation | Skills, rules, hooks, knowledge bases, and the repo's roadmap — organizational knowledge, not just chat history |
| **Share a complete config** | Copy and paste a prompt, by hand | Packages: a self-contained `.zip` with dependencies resolved and auto security review |
| **Multiple providers in the same system** | One per session, chosen when opening | Each agent declares Claude, Codex, OpenRouter, or DeepSeek; all can coexist in one project |
| **See multiple agents' work in progress at once** | Doesn't apply — it's a conversation with one | The Map: resolution nodes, dependencies, evidence, and bounded subagents in real time |

## What this doesn't mean

It doesn't mean Keel is "better" at writing code — the model that writes code is literally the same binary of Claude Code or Codex CLI running underneath, with the same context and the same capabilities of that CLI version. A Flutter agent inside a Keel project reasons just as well (or just as poorly) as that same agent run by hand in a terminal.

It also doesn't mean a terminal CLI or an IDE extension is insufficient for its own use case: for one person working alone on one repo, with no need to coordinate fixed roles or talk projects to each other, that simpler architecture doesn't have the friction that Keel solves — it's exactly the friction that appears when work grows to multiple agents and multiple repos at once.

**And there is no technical moat.** None of this is impossible to copy: no
patent, no network effect, no proprietary data. It is an architectural decision
the rest did not take, because banning invisible fan-out forces you to build
the identity registry, the gates, and the Map before anything works at all —
and anonymous fan-out demos better. What does accumulate, and does not travel
with a `git clone`, is the library of rules, skills, and agents distilled from
real projects.

## Where the real value is

Keel's value surface is not "a better autocomplete" or "a prettier chat". It is coordination of work between agents and projects at organizational scale, backed by concrete pieces already explained in this folder:

- **Roles, not people** — the same workflow works across projects with different stacks because its resolution owner is a role, not a specific agent ([04 — Delegation and teams](04-delegation-and-teams.md)).
- **Communication between projects without sharing context** — a requirement crosses the boundary with the minimum necessary, never with access to the other repo ([05 — Multiple projects](05-multiple-projects.md)).
- **Export/import complete config as a portable unit** — a package carries its dependencies resolved and passes auto security review before install ([08 — Import, export, and packages](08-import-export-and-packages.md)).
- **Multi-provider in the same system** — claude and codex coexist in the same project, each agent with its own ([07 — MCPs, integrations, and providers](07-mcps-integrations-and-providers.md)).
- **Persistence of organizational knowledge** — skills, rules, and knowledge bases survive any single session, and a project's roadmap lives versioned in the repo itself, not in a chat log ([03 — Projects, sessions, and workflows](03-projects-sessions-and-workflows.md), [06 — Agents, skills, rules, and hooks](06-agents-skills-rules-hooks.md)).

## Closing

Back to the index: [README of this folder](README.md).
