# F48 — Keel AI supervises on request, workflow lint, four-node template

## Problem it solves

Keel AI could read sessions, but only the last messages with 400-character
previews: it did not see the case (nodes, closures, findings, cost) nor the
pending decisions, and it had no way to answer one or to send an instruction
into a running session. And it built redundant workflows: the default template
carried eleven nodes, the database held 156 sentences repeated across
instructions, `validateWorkflowCapabilities` only looked at ids, dependencies,
and cycles, and the invariants ("don't add two auditors out of habit") lived in
the prompt.

## Decision

**Four new tools, only at the user's request.**

- `inspect_session(project, session, full)`: state, cost, request, the case with
  a node table (id, title, state, owner, attempts, cost, last closure with
  verdict), a deterministic summary (`sessionDigest`, F46), open findings,
  pending decisions with their id, and — with `full` — the last 20 messages
  untrimmed plus the subagents with their results.
- `intervene(project, session, text)`: if the session is running, it queues and
  interrupts (the node resumes afterward, F43); if not, it opens the next turn.
  It is marked as placed by Keel AI on the user's behalf.
- `answer_decision(project, session, decision_id, answer | approve, scope)`:
  answers a pending decision (F44/F45) with what the user decided.
- `lint_workflow(capabilities)`: the lint without creating anything.

Keel AI's prompt has a "REVIEWING A SESSION" section: inspect first, form an
opinion with evidence (it may contradict the closure an agent declared if the
messages show otherwise), act only on the user's decision. There is no automatic
trigger: Keel AI does not intervene on its own.

**Lint in code.** `lintWorkflowCapabilities`
(`modules/workflows/model/workflow_capability.dart`) runs in
`createWorkflow`/`updateWorkflow` (errors reject) and in `lint_workflow`:

| Severity | Rule |
|---|---|
| error | more than 8 required nodes |
| error | `manualApproval` with `activation: optional` (it never instantiates) |
| error | a node that audits (auditor/reviewer role, or read-only over a node that writes) without `outputContract: audit-feedback` |
| warning | more than 6 nodes in total |
| warning | two nodes with the same role and near-identical contract (Jaccard ≥ 0.8) |
| warning | a node that writes with no declared ceiling |
| info | a required node with no dependencies that is not the first |

**Four-node template.** General and bug: `plan` (read-only, 6 turns) →
`implement` (20) → `audit` (its own session, independent owner,
`audit-feedback`, 6) → `deliver` (resumes `implement`'s session, 6,
`approvalRequired`). No correction nodes: a NO-GO returns the audited node
alone (F44). The audit runs in its own session and not as a native subagent: the
subagent failed in 149 runs and the fallback was the thing doing the auditing.

**Migration.** Keeps the impact inventory and the coverage matrix, with no
correction nodes: `planner → impact → implementation → code-audit → tests →
test-audit → verification (approvalRequired)` plus an optional `device-e2e`.
Seven required: it passes the lint.

The 31 stored workflows keep their capabilities; the lint only acts on create or
update.

## What does not change

- Keel AI still receives no hooks and no permission gate.
- There is no "ask Keel AI to review" button in the session header: you ask it
  from its chat with the project and session names (or by pasting a message
  reference).

## How to verify it

- `test/workflows/workflow_lint_test.dart`: the old template's shape errors on
  count and on optional approval, warns on duplicated audits and nodes with no
  ceiling; the new one passes clean and is four nodes.
- `test/assistant/keel_ai_supervisor_tools_test.dart`: `inspect_session` shows
  nodes, closures, and the decision with its id; `answer_decision` answers it;
  `lint_workflow` flags the optional approval.
- `test/workflows/workflow_execution_test.dart` and
  `test/projects/resolution_engine_test.dart` updated to the new templates.
