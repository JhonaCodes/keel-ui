# F44 — Turn closure (`keel-outcome`), real gates, and pending decisions

## Problem it solves

The engine had no way of knowing how a turn ended. It inferred from prose:

- **"No text" meant failure.** `ok = !turnFailed && answer.isNotEmpty`: a node
  that worked through tools and stayed quiet was recorded as a compiler finding
  and burned a reformulation.
- **Verdicts did not exist for the engine.** There were 197 `VEREDICTO: GO` and
  `NO-GO` written in prose in the database; none of them moved a node. The
  policy's `qualityGates` was never evaluated.
- **There was no "it is asking you".** An agent that closed a turn with a
  dangling question left the session with nobody aware it was waiting. Worse:
  `PlanReadyBanner` fired anyway ("shall we implement?") even though it had only
  asked.
- **The turn cap meant failure.** Reaching `--max-turns` recorded a finding and
  reformulated the node, even when the work was nearly done.
- **Manual approval never fired.** In the stored workflows every `manualApproval`
  was `optional`, and the engine only instantiates `required`.

## Decision

**The block.** Every node turn ends with:

```
```keel-outcome
status: done | blocked | needs_user | needs_permission | failed
summary: what changed and what evidence validates it
files: paths touched
artifacts: PR, test command, report
verdict: GO | NO-GO         (mandatory on nodes with output_contract audit-feedback)
next: id of an optional capability to activate
question: only with needs_user / needs_permission
```
```

`parseKeelOutcome` (`modules/projects/model/turn_outcome_report.dart`) reads the
LAST valid block of the turn with the same `parseFencedBlocks` as ```cobertura.
The spec travels in the system prompt only on node turns
(`kOutcomeProtocolPrompt`), never in consultations or 1:1 chats.

**The engine decides from the block.** `ResolutionEngine.applyOutcome` is pure:

- `done` → node `done`, output stored in `WorkNode.output`, assigned findings
  resolved.
- an audit with `NO-GO` → a `review` finding on the audited node (or the first
  dependency), that node returns to `pending`, the audit does too (it re-runs
  after the correction), `reviewCycleCount + 1`. The same fingerprint twice
  blocks the case.
- `blocked` / `failed` → a `contract` finding with the summary, node retried up
  to `maxReplans`.
- `needs_user` / `needs_permission` → node `paused` and a pending
  `SessionDecision`.
- `next` → the ViewModel activates the optional capability through the path that
  already existed (`activateWorkflowCapability`).

**A follow-up, not a guess.** A turn that closed without a block — or an audit
with no verdict — receives ONE single-step turn over the same session
(`kOutcomeFollowUpPrompt`) that asks only for the status. If there is still no
block: `done` with the text as summary if it spoke, `blocked` if it stayed quiet.
An audit that gives no verdict counts as `blocked`.

**The turn cap is not a failure.** `hitTurnCap` marks `capHit`, leaves a system
message with the number, and the node goes through the same follow-up.

**Decisions: a single waiting model.** `SessionDecision`
(`kind: question | permission | approval`) lives in `Session.decisions`,
persisted. `Session.waitingForUser` is the signal. The `SessionDecisionCard` sits
above the composer, ahead of the post-hoc permission and the plan banner, and
`shouldAskToImplement` gains an `askedUser`: if the agent asked, implementing is
not offered.

**The answer reaches the agent.** `answerSessionDecision` marks the decision,
returns the node to `pending`, leaves the answer in the thread as a user message,
and calls `resumeWorkflow`. Since the CLI session is resumed with the new prompt
and does not read the thread, the node's answers go inside its instruction ("USER
ANSWERS to what you asked earlier").

**`approvalRequired` on the capability.** Before running a node that declares it,
the engine creates an `approval` decision, pauses the node, and waits. Approving
runs it; rejecting blocks the case there. It is the way to request approval to
publish without a separate node. `manualApproval` still exists for what is
stored. It is edited on the form (a switch) and in `create_workflow` /
`update_workflow` (`approval_required`).

**Audit reports travel through what was declared.** `_auditReportsFor` reads
`WorkNode.output` first (verdict, summary, files) and falls back to the thread
only for nodes that closed before the block existed.

## What does not change

- `qualityGates` remains informational; the real gate is the audit node's
  verdict.
- Permissions remain post-hoc; `needs_permission` closes the turn and waits. The
  permission that suspends the process without closing the turn is the next
  phase, and it reuses this same queue.
- Codex receives the block's spec only on turn 1 of its session; the follow-up
  repeats it in its own prompt. `--output-schema` is left for the context phase
  and Codex.

## How to verify it

- `test/projects/turn_outcome_report_test.dart`: an embedded block with NO-GO,
  the last block wins, status variants, JSON.
- `test/projects/resolution_engine_test.dart` (`applyOutcome`): NO-GO → audited
  node `pending` + `review` finding + audit `pending` + `canComplete` false;
  correction + GO → finding resolved; `needs_user` → node paused + decision;
  `next`; `blocked`.
- `test/workflows/workflow_execution_test.dart`: decisions survive disk and
  `waitingForUser` reflects what is pending.
- `test/agents/plan_mode_test.dart`: `askedUser` turns off the plan banner.
- In the app: a node that asks leaves the "WAITING ON YOU" card; on answering,
  the node starts again with the answer and without asking the same thing twice.
