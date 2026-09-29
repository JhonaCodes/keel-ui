# F52 — OpenCode as a provider, live model catalogs, API permissions

## Problem it solves

- OpenCode was detected on the machine but had no adapter.
- Codex offered models its own CLI did not know: Keel read
  `~/.codex/models_cache.json`, which another codex (the desktop app, a newer
  version) also writes, and fell back to a hardcoded list of stale slugs.
- OpenRouter/DeepSeek in a 1:1 chat could never ask for permission: a tool
  not granted was simply not offered. Their edits left no diff (the tool
  bridge uses `path`, the diff collector read only `file_path`), and one MCP
  server that did not answer aborted the whole turn.

## Decision

**OpenCode runs as `opencode serve`**, one server per conversation (a live
session, like claude) or per project turn (`OpenCodeRunner`). `opencode run`
was discarded: a non-interactive run rejects every permission `ask` by
itself. The server publishes `permission.asked` on `/event` and takes the
answer on `/permission/{id}/reply`; the runner asks Keel's gate (the same
card, once / always / deny) and answers. Per turn it gets a 0700 config file
(`OPENCODE_CONFIG`): Keel's MCP servers with secrets as `{env:VAR}` and a
long timeout, and a permission map — reads free, commands and edits `ask`
(or `deny` in a turn that may not write). It starts with `--pure` (no JS
plugins), so the catalog's shell hooks do not apply to OpenCode. Tool names
are translated to Keel's (`bash` → `Bash`, `edit` → `Edit` with
`file_path`). Verified against OpenCode 1.18.29, including a real turn.

**Models come from the CLIs**, through one shared catalog with a 10-minute
lifetime (`ModelCatalogService`):

- Codex: `codex debug models` from the same binary that runs the turns,
  `visibility: list`, in its priority order, with each model's reasoning
  levels. Without the CLI only "whatever your codex config uses" remains.
- OpenCode: `opencode models --verbose`, only models that can call tools;
  their variants are their effort levels.
- Claude stays as it was (no listing command, and no API key is used).

The effort sent is one the model accepts: codex forwards the level verbatim
and the API rejects a level the model lacks.

**API providers in the 1:1 chat** carry the gate: Write/Edit/Bash are offered
and each call asks. The diff collector also reads `path`, and an MCP server
that fails to load is skipped with a notice in the thread.

**At most 4 subagents at once** (`SubagentLimits.maxParallel`), for every
provider — each one bills as a whole model:

- Claude: `PreToolUse` on `Task` (claude reports `Agent`; `Task` matches it)
  counts one up or denies, `SubagentStop` counts one down. `PostToolUse` fires
  when a background subagent is *launched*, so it cannot say when it ended
  (verified with claude 2.1.280).
- Codex: `-c agents.max_threads=4` and
  `-c agents.max_concurrent_threads_per_session=4` on every turn (default 6).
- OpenCode: `task` asks, and the runner answers by itself with how many are
  running. Child sessions opened by `task` are tracked, so their permission
  requests reach Keel's card instead of hanging.
- Workflows: the per-node subagent quota tops at 4 (it was 6, default 5).

## How to verify it

- `test/run_agent_opencode.sh`: a fake `opencode serve` (the real API
  shapes): the permission card appears, the answer reaches OpenCode, the reply
  lands in the chat.
- `test/run_opencode_real_binary.sh`: the real binary with a free model.
- `test/run_agent_codex_chat.sh`: codex models come from `codex debug
  models`; the effort sent is one the model accepts.
- `test/hooks/subagent_parallel_guard_test.dart`: the real script lets four
  run at once, denies the fifth, and frees a place on `SubagentStop`.
- `test/core/file_edit_collector_test.dart`,
  `test/llm/openai_compatible/openai_tool_bridge_test.dart`.
