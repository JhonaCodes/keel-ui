# Keel's documentation

Each file in `features/` tells **one** thing: what problem it solves, how it is
solved, and which decisions were taken along the way that are not visible in the
code. They are numbered by order of appearance, not of importance.

If you are coming from outside, the [README](../README.md) has the complete mental
model; this is the detail. For the product view rather than the implementation,
start at [`product/`](product/README.md).

## The foundations

| | |
|---|---|
| [F0](features/00-multi-window-foundation.md) | Multi-window foundation |
| [F1](features/01-assistant-window.md) | Keel AI's window |
| [F2](features/02-compiled-keelai-and-builders.md) | Compiled Keel AI + builder agents |
| [F15](features/15-keelai-full-catalog.md) | Keel AI with the full catalog |

## What an agent wears

| | |
|---|---|
| [F3](features/03-global-skills.md) | Global skills |
| [F4](features/04-secrets.md) | Secrets hidden from the LLM |
| [F5](features/05-external-mcps.md) | External MCP integrations — the mechanism |
| [F28](features/28-integrations-catalog.md) | The catalog, and being able to test them |
| [F16](features/16-knowledge-bases.md) | Knowledge bases |
| [F22](features/22-hooks.md) | Hooks: guardrails that run on their own |
| [F39](features/39-catalog-locks.md) | Locks: what a tool cannot touch on its own |
| [F6](features/06-codex-provider.md) | Codex provider per agent |
| [F18](features/18-engine-per-project.md) | A member's engine, per project |

## Working

| | |
|---|---|
| [F24](features/24-projects-and-sessions.md) | A project, and its sessions |
| [F17](features/17-session-plan.md) | A session's work plan |
| [F23](features/23-project-roadmap.md) | A project's roadmap |
| [F25](features/25-project-status.md) | A project's status |
| [F26](features/26-internal-requirements.md) | Requirements between projects |
| [F50](features/50-target-activity-in-requirements.md) | What a requirement's target project is doing |
| [F8](features/08-session-scoped-agent.md) | Session-scoped agent |
| [F29](features/29-boards.md) | Test boards |
| [F32](features/32-single-navigation.md) | A single navigation |
| [F42](features/42-sidebar-groups.md) | Arranging the sidebar: groups and order |
| [F34](features/34-worktrees.md) | Working in another worktree, and coming back |
| [F37](features/37-adaptive-workflow-per-session.md) | Adaptive workflows per session |

## The conversation

| | |
|---|---|
| [F13](features/13-images-in-chat.md) | Images in the chat |
| [F14](features/14-message-queue.md) | Writing while the agent works |
| [F19](features/19-links-and-session-pr.md) | Clickable links and the session's PR |
| [F7](features/07-economical-communication.md) | Economical communication + the ledger |
| [F10](features/10-recurring-skill-suggestions.md) | Recurring skill suggestions |
| [F11](features/11-knowledge-section.md) | The Knowledge section |
| [F38](features/38-chat-references.md) | Explicit references in the chat |
| [F40](features/40-references-in-every-chat.md) | The same references, in every chat |
| [F49](features/49-chat-filters-and-retry.md) | Filters, subagents in view, retry, and a persisted live turn |

## The machine

| | |
|---|---|
| [F20](features/20-single-file-backup.md) | Single-file backup |
| [F21](features/21-system-vault.md) | The system vault |
| [F33](features/33-packages.md) | Packages: sharing a whole agent |
| [F12](features/12-jobs-api.md) | Local scheduled-jobs API |
| [F27](features/27-startup-and-waiting.md) | Startup, and saying that you are waiting |
| [F30](features/30-machine.md) | Services, consumption, and hardware |
| [F31](features/31-resolution-map.md) | The map: seeing how it thinks |
| [F35](features/35-failure-log.md) | The failure log |
| [F36](features/36-updating-keel.md) | Which Keel you are running, and updating it |
| [F41](features/41-roots-and-volumes.md) | Other disks, and where your projects are |

## The turn engine

| | |
|---|---|
| [F43](features/43-turn-caps-and-watchdog.md) | Default caps, turn watchdog, and resuming after an interruption |
| [F44](features/44-turn-closure-and-decisions.md) | Turn closure (`keel-outcome`), real gates, and pending decisions |
| [F45](features/45-blocking-permissions.md) | Permissions and questions that suspend the turn |
| [F46](features/46-context-between-nodes.md) | Context between nodes, session reuse, and the prompt budget |
| [F47](features/47-subagent-quota-in-code.md) | The subagent quota is enforced in code |
| [F48](features/48-keelai-supervisor-and-lint.md) | Keel AI supervises on request, workflow lint, four-node template |
| [F51](features/51-codex-first-class.md) | Codex with the same surface as claude |

## The rest

- **`product/`** — the product view: what Keel is, navigation, delegation between
  members, providers, and how it differs from other tools.
- **`mockup/`** — the drawings approved before any Dart was written:
  [projects and requirements](mockup/proyectos-y-requerimientos.html),
  [integrations, boards, and machine](mockup/integraciones-tableros-y-maquina.html),
  and [the reasoning map](mockup/mapa-de-razonamiento.html). They are built with the
  exact tokens of `app_theme.dart`, so they serve as the reference for what the UI
  has to look like.
- **`templates/TASKS/`** — the skeleton of a project roadmap (F23), to copy into a
  repo.
- **[Build and distribute](build-and-distribute.md)** — how what people download is
  produced: macOS, Linux, and why Windows not yet. It is not a feature; it is the
  process, with each platform's constraints and the traps that already cost us once.

> There is no F9. It was numbered and never written, and renumbering twenty files to
> cover a gap costs more than it is worth.
