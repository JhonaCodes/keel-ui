# F45 — Permissions and questions that suspend the turn

## Problem it solves

Permission arrived late and cost too much. The CLI ran with nobody to answer it:
a tool that was not allowed got denied on its own and the turn carried on. Keel
only found out from the denial event, showed a card, and "Allow" did two bad
things at once: it changed a **global app setting** (from then on every agent had
that tool, always) and started a **new** turn with "pick up where you left off",
which re-paid for the context and re-derived the work. A second request for the
same tool was swallowed silently, the card was not persisted, and only one was
shown at a time.

And an agent that needed a value from the user had no choice but to close the
turn asking for it (F44 gave it `needs_user` for that), losing the live process.

## Decision

**A gate that waits, across all three providers.** `keel-decision-gate` is an
internal `PreToolUse` hook that Keel adds to every member's turn, over the tools
that write (`Bash`, `Edit`, `Write`, `MultiEdit`, `NotebookEdit`). The script
(Python, ships with macOS) sends `{tool_name, tool_input}` to the loopback
decisions server and **waits** for the answer; it returns the
`permissionDecision: allow | deny` contract that claude and codex understand, and
that the APIs' bridge now also reads from the hook's output. The hook's deadline:
six hours, the same criterion as `kMcpToolTimeoutMillis`. If Keel does not
answer, it is deny — never allow by default.

With the gate in place, those tools enter the CLI's allow-list — otherwise the
CLI denies them on its own, without asking — and it is the gate that decides. A
project you do not maintain still gets no write tools; a consultation does not
receive them either.

**Scoped grants.** The gate answers instantly if the permission is already
granted at any of three levels, and otherwise queues a decision and waits:

| Scope | Where it lives | Who decides |
|---|---|---|
| Just this once | nowhere | the card |
| This session | `Session.grantedTools` | the card |
| This agent here | `Project.grantedToolsByProfileId` | the card |
| Always | `AppSettings.extraAllowedTools` (what used to be the only level) | the card or Settings |

**`ask_user`.** The decisions server also exposes an MCP (`keel-decisions`) with
a single tool: `ask_user(question, options)`. It suspends the turn until the
answer arrives and returns it within the same turn, with the process and the
context still alive. `needs_user` (F44) remains as the fallback for whoever
cannot call tools (codex receives no MCPs).

**One single queue.** Both things create a `SessionDecision` (F44) with
`blocking: true`: there is a live process waiting. The turn watchdog pauses
meanwhile (waiting on a person is not agent inactivity) and resumes on answer.
`answerSessionDecision` completes the wait and continues; for non-blocking
decisions (a node closed with `needs_user`, an approval) it does what F44 says:
unblocks the node and resumes the workflow.

**Stop and restart.** Stopping the session answers whatever is pending with
`cancelled`: the hook receives deny and nobody is left waiting. On reopening the
app, a pending blocking decision is cancelled (the process that was waiting died
with the app); a non-blocking one survives, because the node is paused on disk.

**Server.** `DecisionGateServer` (`integrations/decisions_mcp/`): a single
loopback process with a per-launch token. `POST /gate/{project}/{session}/
{profile}` for the hook and `POST /ask/{project}/{session}/{profile}` for the
MCP. The route carries the scope, like the other in-house MCPs: a turn cannot ask
for permission on another's behalf. `tools/call` has no server-side deadline.

## Known limits

- **Codex.** Since F51 the gate travels through `-c hooks.PreToolUse=[...]` on
  exec and on resume, with `--dangerously-bypass-hook-trust`: without that flag
  codex 0.153 silently ignores a hook generated per turn (verified against the
  binary). The hook's contract is the same as claude's.
- **Denials from the user's own hooks** (`kHookDenialMarker`) remain post-hoc by
  design: a guardrail that blocks does not ask.
- The old post-hoc permission banner stays for the case the gate does not cover
  (an MCP tool outside the allow-list); "Allow" there is still global.

## How to verify it

- `test/hooks/decision_gate_hook_test.dart`: claude receives the `PreToolUse`
  with a write matcher, a long deadline, and a script with `permissionDecision`;
  codex receives it as a `-c` override; with no gate and no catalog there are no
  hooks.
- `test/projects/session_decision_queue_test.dart`: two requests queue two
  decisions; granting "this session" completes only the first and lands in
  `grantedTools`; the same tool no longer asks; Stop cancels the other; a
  blocking question returns the answered text.
- In the app: an agent runs `git push`; the process stays alive (`ps`), the
  WAITING ON YOU card shows the command, "This session" lets it through and never
  asks about `Bash` again in that session.
