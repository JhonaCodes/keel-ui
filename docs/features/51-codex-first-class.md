# F51 — Codex with the same surface as claude

## Problem it solves

A node owned by codex ran blind. It received no MCP server at all (not the plan,
not `ask_user`, not requirements), its identity travelled wrapped inside the
user's prompt and was repeated on every resume, it had no turn ceiling (codex has
no `--max-turns`), and with codex 0.153 the hooks Keel handed it — the permission
gate included — **did not run and nobody found out**: the binary demands
persistent "trust" for each hook, and Keel's are generated per turn. On top of
that, `exec resume` stopped accepting `-p <profile>` and rejects `-c profile=` as
legacy, so the per-turn TOML profile covered no more than the first turn of each
session. And the installed binary (0.149) rejected the default model from the
user's config: every codex turn failed with a 400.

## Decision

Everything configurable about a codex turn travels through `-c key=value`, which
is the only thing `exec` and `exec resume` accept alike (verified against codex
0.153.4 on 2026-09-05, capturing the requests with a fake provider):

- **Role instructions** → `-c developer_instructions="..."`, on the first turn
  only. Codex persists them in the thread as a developer message and re-sends
  them on every resume; sending them again meant paying for them twice. The
  user's prompt stays clean (`buildCodexPrompt`: request + plan mode).
- **Hooks** → `-c hooks.<Event>=[...]`, one override per event
  (`renderCodexOverrides`), plus `--dangerously-bypass-hook-trust` when there is
  any. Without that flag codex ignores the hook silently; with it, the hook runs
  and the contract is claude's (`tool_name: "Bash"`, `permissionDecision`). The
  permission gate (F45) now covers exec **and** resume.
- **MCP** → `-c mcp_servers.<name>.url=...` for HTTP, `command`/`args` for
  stdio (`codexMcpConfig`, over the same `mcp.json` claude receives). Secrets
  never go in argv: headers travel via `env_http_headers` pointing at process
  environment variables, and a stdio server's `env` is forwarded through
  `env_vars` (codex's children do not inherit the environment). With this, a
  codex node has the plan, decisions, roadmap, requirements, boards, and the
  user's tools, just like claude. The ```plan fenced-block mirror that existed
  for codex was deleted: it has the tools now.
- **Turn ceiling** → the `keel-tool-cap` hook: it counts tool calls and denies
  the one exceeding `maxTurns × 3` (`kCodexToolCallsPerTurn`) with a reason that
  asks it to close with `keel-outcome`. The preflight says so.
- **Binary** → updated to 0.153.4 (`npm i -g @openai/codex`); the default model
  works again.

`CliTurnWorkspace` no longer writes profiles into `$CODEX_HOME`; only the hook
wrappers, and it returns the overrides with the real path.

## What is still different

- Codex does not report cost: the per-session cost ceiling does not stop it. The
  tool cap, the watchdog, and the thread's token ceiling do.
- The subagent quota (F47) remains claude's: codex has no `Task`.
- The user's global config (`~/.codex/config.toml`: their own MCPs, plugins,
  skills) is loaded on every Keel turn. It is the user's and is not touched.

## How to verify it

- `test/llm/codex/codex_cli_runner_test.dart`: a fake `codex` dumps argv and
  environment; the gate travels via `-c` with the trust flag, the MCP bearer is
  in the environment and not in argv, `developer_instructions` goes only on exec.
- `test/llm/codex/codex_config_overrides_test.dart`: the translation of
  `mcp.json` into overrides, HTTP and stdio, with no secrets in the overrides.
- `test/hooks/tool_cap_hook_test.dart`: the real script lets N through and denies
  N+1, asking for closure.
- `test/hooks/decision_gate_hook_test.dart`: codex receives the gate as an
  override.
