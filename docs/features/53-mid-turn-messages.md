# F53 — Messages that reach a running turn without cutting it

## Problem it solves

- "Send now" in a session (and Keel AI's `intervene`) always went through
  `stopSession(interrupting: true)` (F43): the CLI process was killed and the
  step in flight was lost (a test running, an edit halfway).
- The interruption then cost **two** new processes: one turn for the message,
  and one that ran the node again with its full contract (`adaptiveNodePrompt`:
  "Pedido original… Eres el agente asignado al nodo…"). The agent read that as
  a new assignment and re-oriented from scratch: it read the repo again and
  re-verified what it had already done. Each intervention cost minutes and
  tokens, and an agent being corrected often looked stuck.
- The premise behind it ("the CLI opens no channel for text mid-turn") was
  wrong for claude: `claude -p --input-format stream-json` keeps reading stdin
  while it works, and the 1:1 chat already used it (`ClaudeLiveSession`).

## Decision

**Claude: the message enters at the agent's next step.** The per-turn runner
(`ClaudeCliRunner`) now starts `claude -p --input-format stream-json` and
writes the prompt as the first stdin line (`claudeUserLine`), keeping stdin
open while the model works. A message sent "now" is written as another user
line with `priority: "next"`; the CLI hands it to the model at the next tool
boundary, inside the same turn. Stdin closes at the first `result`; whatever
was already written is still answered (as a follow-up turn in the same
process if the model had finished) before the process exits. Probed against
CLI 2.1.280:

- `next` (and the default, without `priority`) entered mid-turn: one
  `result`, the model used the message, exit 0.
- A message written during a turn with no tool calls ran as a second turn in
  the same process, even after stdin was closed.
- `result.queued_turn_count` stayed at 0 in both cases, so Keel does not rely
  on it.
- `total_cost_usd` is cumulative per process (0.0041, then 0.0100 with fewer
  tokens). `ClaudeStreamReader` now reports each `result` as the delta from
  the previous one, which also fixes the 1:1 chat's live process, where every
  turn re-counted the earlier ones.

The prompt no longer travels in argv either, so it is not visible with `ps`.

**Delivery is acknowledged.** `LlmRunner.run` takes a `steer` stream; only
targets that `dispatchLlmSteering` marks (exhaustive switch, no `default`:
today only `Claude(ClaudeCli)`) deliver it. Every text written to stdin comes
back as a `steerDelivered` event (`TaskSteerDelivered`). In the view model:

- `_runTurn` registers the work turn of a session (never a consult) in
  `_workTurns`: run, member, node, execution id.
- `sendQueuedSessionMessageNow` first tries `_steerQueuedMessage`: if there is
  a work turn that can steer and the message does not name another agent, the
  message (with its references and attachments, `_channelPrompt`) goes to
  `TaskRun.steer`, leaves the queue, and the thread says «Entregado a @x en su
  próximo paso, sin cortar el turno». No `stopSession`; the node stays
  `running`.
- A steered message without an acknowledgement when the turn ends (stdin
  already closed, isolate gone) goes back to the queue: after the turn, or on
  hold if the user pressed Stop.

**Other providers: one continuation turn.** Codex, OpenCode and the API
runners take no input mid-turn, so "now" still cuts the turn, but:

- `stopSession(interrupting: true)` remembers the cut node and its execution
  id (`_interruptedNodes`).
- When the message leaves the queue, `_resumeInterruptedNodeWith` puts it
  inside that node's next turn instead of opening a separate one, and resumes
  the workflow.
- If the node resumes its own CLI session, it gets `nodeContinuationPrompt`
  ("CONTINUACIÓN DEL NODO …: not a new assignment; apply the message and go on
  from the last completed step; do not re-verify"). Without that session
  (compaction, discarded session) it gets the full contract plus a
  «MENSAJE DEL USUARIO QUE CORTÓ TU TURNO ANTERIOR» section.

Keel AI's `intervene` description, its reply, and the system map say which of
the two happened (`canSteerSession`).

## What does not change

- A message typed in the channel while a turn runs still waits in the queue
  (standby, "after this turn", or "now").
- Stop still kills the process and seals the session.
- The 1:1 agent chat keeps its queue; steering it is a separate change.

## How to verify it

- `test/llm/claude/claude_cli_runner_test.dart`: a fake claude gets the
  message on stdin with `priority: next` mid-tool, the turn keeps going and
  stdin closes at the first `result`; a message after the `result` gets no
  acknowledgement.
- `test/map/claude_stream_reader_test.dart`: two `result`s of one process
  report the delta of the cumulative cost.
- `test/run_session_steer.sh`: real isolates and processes. "Send now" on a
  claude node: one process, the message on its stdin, no «Turno
  interrumpido». On a codex node: the cut turn plus ONE resumed turn whose
  prompt is the continuation with the message, not the full contract.
- `test/run_workflow_continuation.sh`: the full workflow with the prompt on
  stdin.
- In the app: while a claude node works, write in the channel and choose
  "send now" (or ask Keel AI to intervene). The thread shows «Entregado a @x…»,
  the agent reacts at its next step, the node stays running, and the Machine
  screen shows the same PID.
