# F46 — Context between nodes, session reuse, and the prompt budget

## Problem it solves

Every node started from scratch. A `newSession` node opened a fresh CLI session
and received only the original request, its contract, and the findings in one
line: the previous node's output did not travel (only with `outputContract:
audit-feedback`, which no stored workflow used). `resumeParent`, the only
executor that kept context, was used by zero workflows. Result: `audit` and
`deliver` re-read the repo `implement` had just walked; one node reached 248
million tokens of cache reads.

The system prompt also had no ceiling: whole skills and rules, a profile with 37
thousand characters; `_subagentPacket` sent the auditor's skills, rules, and
system prompt inside the instruction, and the fallback sent them again as a
system prompt. And codex lost its identity on every resume: the preamble only
went out on turn 1, and `exec resume` discarded the sandbox and the hooks
profile.

## Decision

**The output travels.** With the closing block (F44), each node leaves
`WorkNode.output`. `dependencyOutputs` + `renderDependencyOutputs`
(`modules/projects/service/node_context.dart`) build the instruction's section
"WHAT THE NODES YOU DEPEND ON LEFT BEHIND": title, verdict, summary, files, and
artifacts, each trimmed to 1,500 characters. When there are closed nodes that
are not direct dependencies, "STATE OF THE CASE SO FAR" is added:
`sessionDigest`, deterministic, node by node, with no thread bodies, up to 4,000
characters.

**Reusing the owner's session.** With `WorkflowPolicy.reuseOwnerSession`
(default true), a `newSession` node whose owner already closed a dependency
resumes that dependency's CLI session (`reusableDependencyId`: same owner,
closed dependency, live session, and the node does not demand an independent
owner; it looks from the last dependency back to the first). The thread says so.
A turn's follow-up (F44) lands in the same session because the choice is
deterministic.

**Compaction without an LLM.** Before resuming (reuse or `resumeParent`), if
`Session.contextUsageRatio` exceeds `compactAtContextRatio` (default 0.7), that
CLI session is discarded and the node starts fresh with its dependencies' output
and the digest in the instruction. The summary IS the compaction; there is no
extra turn and no different model.

**System prompt budget.** `_turnSystemPrompt` builds sections with a trimming
priority (`PromptSection`, `budgetTurnSystemPrompt` in `turn_prompt.dart`): the
knowledge brief goes first (3), then the assigned skills the policy does not
require (2), then global skills beyond the first two (1). Identity, rules,
required skills, and contracts never. Ceiling `systemPromptMaxChars` (default
60,000). When it trims, `Log.w` says how large it was and what was removed.
Knowledge and the plan still go last, for the cacheable prefix.

**Codex on resume.** `buildCodexArguments` sends `-c sandbox_mode=...` and
`-c profile=...` when resuming (verified: `exec resume` accepts `-c`), so plan
mode has a brake and the hooks profile — with F45's permission gate — applies on
resumed turns too. And the role preamble is no longer discarded: the ViewModel
sends the COMPACT version of the prompt (identity, rules, and contracts; no
skills and no knowledge, which are already in codex's thread) and
`buildCodexPrompt` prepends it on every turn. The "resumed without sandbox or
profile" warnings are gone because they stopped being true.

**A smaller audit packet.** `_subagentPacket` carries the contract, the touched
files, and the instruction; not the auditor's skills, rules, or system prompt,
which already travel as its system prompt when it falls back.

## What does not change

- An explicit `resumeParent` still beats implicit reuse.
- `--allowedTools` does not change between nodes of the same resumed session (it
  was already like that for `resumeParent`).
- `-c profile=` on codex is not verified against the binary (the user's CLI does
  not accept its models today); if codex ignores the key, the resume runs without
  hooks as before, not worse.

## How to verify it

- `test/projects/node_context_test.dart`: dependency outputs with trimming, the
  digest, and the choice of session to reuse (same owner, closed, live; never
  with an independent owner).
- `test/system_prompt/adaptive_node_prompt_test.dart`: the dependency's output
  and the digest come before the closing contract.
- `test/projects/turn_prompt_test.dart`: the budget removes knowledge first, then
  skills; rules and identity survive.
- `test/llm/codex/codex_arguments_test.dart` and `codex_cli_runner_test.dart`:
  `-c sandbox_mode`, `-c profile`, the preamble on resume, no warning.
- `test/workflows/workflow_model_test.dart`: the policy's three new fields
  survive disk.
- In the app: in a two-node session owned by the same agent, the second says
  "resumes the session of …" and its input cost drops compared with a session
  with `reuseOwnerSession: false`.
