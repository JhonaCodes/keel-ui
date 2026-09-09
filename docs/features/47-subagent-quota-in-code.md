# F47 — The subagent quota is enforced in code

## Problem it solves

The per-node subagent quota (`WorkflowPolicy.maxSubagents`) was a promise made
in the prompt. `SubagentBudget` merely observed it: by the time the open event
arrived, the CLI had already launched the subagent, and the only thing left to
do was warn once and pay for it in full. A node with a quota of 1 could open
four; a node with a quota of 0 could open one. And subagents without a concrete
question did pointless work, because nobody had asked them for anything
verifiable.

## Decision

**A `PreToolUse` hook on `Task`.** `keel-subagent-guard`
(`integrations/hook_delivery/src/subagent_guard.dart`) is added to every turn of
a claude agent, alongside the user's hooks and the permission gate (F45). It
counts in `subagents.count`, a file in the turn's 0700 workspace — it dies with
the turn — and denies task `N+1` with the reason. A quota of zero denies from
the very first one, which is what the prompt always said and could never
guarantee. Only claude has the `Task` tool; for codex and the APIs there is
nothing to stop and the hook is not added. Codex instead gets the
`keel-tool-cap` hook (F51), same scheme, for its turn ceiling.

**The prompt is still the first line.** `subagentPolicyPrompt` now states that
the quota is enforced in code and that every task must carry a concrete question
and an output contract: a task without a question is wasted quota.
`SubagentBudget` remains as an observer, for the map and the log.

## How to verify it

- `test/hooks/subagent_guard_hook_test.dart`: claude receives the hook with a
  `Task` matcher; the script, run under a real bash, lets two through and denies
  the third and fourth; with a quota of zero it denies; with no quota there is no
  hook.
- In the app: a node with `maxSubagents: 1` that tries to open two tasks sees the
  second denied with "Subagent quota exhausted" in the CLI thread.
