# F6 — Codex provider per agent

## What it is

Each profile/agent declares its **provider** (`AgentProvider`): `claude`
(default) or `codex`. The two-letter badge next to the agent's name (CL orange /
CX green, no trademarks) says which CLI runs it. It is picked on the profile form
(Provider dropdown) and Keel AI sets it with
`create_or_update_agent(provider: "codex")`.

## Adapter (`core/services/codex_cli_service.dart`)

It emits the SAME event stream (`ClaudeEvent`) as the claude adapter — the
consumers (1:1 chat, projects) are provider-agnostic.

Verified against `codex-cli 0.142.3` with a real run:

- `codex exec --json` emits JSONL of the `thread.started` /
  `turn.started|completed|failed` / `item.*` / `error` family. `thread_id` is the
  session id; resume: `codex exec resume <id> --json`.
- **codex reads stdin when it is not a TTY** ("Reading additional input from
  stdin…") — the adapter closes `process.stdin` immediately or the process waits
  for EOF forever.
- codex exits with code 0 even on in-band errors (`{"type":"error"}`) — the
  parser turns those into a visible failure.
- No system-prompt flag → the profile's prompt travels as a delimited preamble on
  the FIRST turn; resumed ones keep it from history.
- Sandbox: full access → `danger-full-access`, otherwise `workspace-write`.

## Models: each provider with its own

The two CLIs share NO model name at all, so the catalog is split by provider in
`agents/model/agent_model_option.dart` (`modelOptionsFor(provider)`). The
selector used to always offer Claude's aliases — even to a codex agent, which
ignored them anyway: picking "Opus 5" on a codex agent did absolutely nothing.

Now:

- The chat's selector and the profile form's list the models of the agent's
  provider. Changing provider on the form resets the model to that provider's
  default (an alias from the other one means nothing).
- The codex list comes from its own catalog, `~/.codex/models_cache.json`,
  filtering `visibility: list` (the same thing its picker offers): `gpt-5.5`,
  `gpt-5.4`, `gpt-5.4-mini`. `gpt-reserve` and `codex-auto-review` are marked
  `hide` and are not offered. If the lineup changes, that constant is updated.
- The first option is **"Whatever your codex config says"** (empty alias): `-m`
  is not passed and codex resolves the model from its `~/.codex/config.toml`. It
  is the default because it never goes stale.
- The model DOES travel now: `codex exec -m <slug>`, both in the 1:1 chat
  (`CodexCliService`) and in projects (the isolate builds its own arguments and
  uses the same rule).
- **Compatibility**: a codex agent created before this split carries a Claude
  alias (`sonnet`). `codexModelArgument()` treats it as "no model" instead of
  passing it to codex, which would reject it; and the form starts on codex's
  default, so saving heals the record.

## v1 limits (on purpose)

- No deterministic tools, no MCPs (external or keelai-actions), no effort: those
  surfaces do not exist in the adapter. The form says so. **The chat's effort
  selector is still visible for codex agents and does nothing** — the same defect
  the model one had, not yet fixed.
- Per-turn cost is reported as 0 (codex does not emit it in the JSONL).

## Projects

`TaskRunSpec.provider` travels to the isolate, which picks the executable, the
arguments, and the parsing dialect (`_parseCodexEventToMessages`, a mirror of the
service — the isolate is self-contained by design).

## The session plan with codex

Codex receives no MCP servers, so the plan's tools do not exist for it — and that
broke the central contract: if step 1's owner was codex, the session ran with no
plan and closure sealed it as "finished". Three pieces fix it:

- **Fenced blocks**: a codex member writes the plan with a ```` ```plan ````
  block (`puntos:` with `text | role` lines) and checks items off with
  ```` ```cumplido ```` — the same pattern as ```` ```agente ````. The app parses
  them when closing its turn (`_applyDeclaredPlanBlocks`) and actually applies
  `setTaskPlan`/`completePlanItems`. The PLAN section of its prompt documents the
  blocks instead of the tools.
- **A fresh plan on resumed turns**: codex receives a system prompt only on the
  FIRST turn of its session, so the plan's state stayed frozen at turn 1. Now, on
  resumed turns, the live PLAN section travels prepended to the turn's request,
  which does always arrive.
- **The closure verifier prefers claude** (`_planCloser`): between the owner of
  the first and the last step, the one not running on codex goes — it has the real
  tools. If there is only codex, it verifies with the blocks anyway.

And closing with an empty plan is no longer an automatic success: if the cycle
ended with no plan and without producing a single work message, the session is
left as NOT finished instead of "finished" — the false success of a mute codex
project is gone.
