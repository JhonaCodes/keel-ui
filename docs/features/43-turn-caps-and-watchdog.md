# F43 — Default caps, turn watchdog, and resuming after an interruption

## Problem it solves

A workflow could get stuck with no signal at all. Four causes, all in code:

- **No real turn cap.** `maxAgenticTurns: 0` meant "unlimited", and 26 of 31
  stored workflows ran that way. One node reached 577 turns.
- **No timeout whatsoever.** A hung CLI emits no events; the turn's `await for`
  waited forever and the session stayed `running` with nothing running. The only
  way out was a manual Stop. One run sat 1 h 51 min in that state.
- **Interrupting broke the flow.** A message sent mid-node called `stopSession`,
  which sealed the session as `failed`, left the node `running`, and never
  returned to `_runWorkflow`. The engine only picks `pending` nodes, so the case
  "would not close".
- **A fallback that could not write.** When Claude did not open the native
  subagent, the node fell back to an external session with `planMode: true`
  hardcoded. A delivery node (commit, push, PR) could never write and burned its
  cap explaining why.

And with no cost ceiling: a session spent whatever the model felt like.

## Decision

**Default caps on the capability.**
`WorkflowCapability.effectiveMaxAgenticTurns` is what reaches `--max-turns`: the
declared value, or 20 if the node writes and 8 if it is read-only.
`maxAgenticTurns` still stores what the user typed; zero is no longer
"unlimited".

**Deadlines and a ceiling in the policy.** `WorkflowPolicy` adds
`idleTimeoutMinutes` (10), `nodeTimeoutMinutes` (45), and `maxSessionCostUsd`
(0 = no ceiling, and that is the default: a case is not cut off on price unless
somebody declares a ceiling). They are edited on the workflow form and stated in
the preflight message, so a cut is never a surprise. Earlier records read the
defaults, and those stored with the old default ceiling lose it exactly once
(`WorkflowsRepository`, marked with
`_workflow_cost_ceiling_default_retired_v1` so as not to overwrite a ceiling
chosen later).

**Turn watchdog.** `TurnWatchdog` (`modules/projects/service/`) wraps the event
stream with two deadlines: an idle one, which every event resets, and a hard one
for the whole turn. Either fires exactly once, cancels the process, and closes
the stream: `_runTurn` exits the `await for` and marks the turn failed with the
reason and the configured number. It has `pause`/`resume` for a turn awaiting a
human decision: that wait is not agent inactivity.

**Cost ceiling.** When picking each node, the engine compares what has been
spent (`SessionUsage.reportedCostUsd`) against the ceiling. If it has been
reached, it blocks the case, says so, and seals the session. What remains travels
to claude as `--max-budget-usd` so it cuts itself off. Only cost the provider
reports counts: codex does not report it, and the preflight warns about that.

**An interruption that resumes.** `stopSession(interrupting: true)` cancels the
turn, returns the `running` node to `pending`
(`ResolutionEngine.releaseRunningNodes`), and does not seal the session. The
message is handled as a follow-up, and when it finishes, `resumeWorkflow` goes
back to `_runWorkflow` if the case is still active and has a ready node. A bare
Stop still seals `failed`. And a turn cut off by Stop or an interruption is no
longer recorded as a compiler finding.

**A fallback with the node's mode.** The external session of a
`providerSubagent` runs with `planMode: capability.readOnly`, not a hardcoded
`true`.

**Sealed exits.** The audit-cycle cap seals the session as `failed` before
exiting. Manual approval is left `running` on purpose: it is a wait, and the
"waiting on you" state arrives with the turn-closure protocol.

**Claude's stdin is closed at startup.** `claude -p` with a non-TTY stdin waits
a few seconds in case the prompt arrives that way, and on timeout writes
"Warning: no stdin data received…" to stderr. The runner did not close stdin
(codex's did), so every turn paid for that wait — and when the turn exited with a
nonzero code (the turn cap, for instance), that warning was the "error" that
appeared in the thread instead of the real reason. Now stdin is closed as soon as
the process starts; the test proves it with a fake POSIX CLI that detects whether
its stdin is still open (bash's `read -t` returns 1 on timeout in macOS's bash
3.2, so it is useless as a probe).

**Tool rounds per API.** The default drops from 200 to 40. Each round re-sends
the full history; 200 rounds per node was the cost multiplier. The constructor
still accepts more for the case that needs it.

## What does not change

- No model is chosen by the engine: the profile decides.
- Permissions remain post-hoc in this delivery; the blocking permission is the
  next one.
- `askProject` and answers in requirement threads already recorded to the ledger;
  they needed no changes.

## How to verify it

- `test/projects/turn_watchdog_test.dart`: idleness, the hard deadline, pause,
  and a stream that ends on its own.
- `test/workflows/workflow_model_test.dart`: the effective cap and a policy with
  deadlines surviving disk.
- `test/projects/resolution_engine_test.dart`: releasing the in-flight node
  leaves the case active with the node `pending`.
- `test/llm/claude/claude_arguments_test.dart`: `--max-budget-usd` only with a
  ceiling.
- `test/llm/claude/claude_cli_runner_test.dart`: the fake CLI does not see stdin
  open and the warning does not reach the failure message.
- In the app: interrupt a workflow with a message; the thread says it resumes,
  the follow-up runs, and the node starts again without the session being left
  `failed`.
