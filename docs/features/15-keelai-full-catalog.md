# F15 — Keel AI with the full catalog

## Goal

Keel AI administers the same architecture the app executes. It does not reason
from JSON files, backups, or historical records: its read tools take the typed
models and the live state of the ViewModels.

The domain is general-purpose. A project may contain any technology, or even work
unrelated to programming. The detected stack serves to select skills, rules, and
knowledge; it is never a global default and never forces a fixed agent topology.

## Working cycle

1. `list_catalog` lists skills, rules, hooks, tools, agents, workflows, projects,
   MCPs, and knowledge bases through short summaries.
2. `list_workflows` returns every complete workflow contract in a single call.
   The optional `names` filter limits the response to exact names and reports
   which do not exist.
3. `list_projects` returns the complete configuration of every project, including
   available and active workflows, assignments, and sessions. Comparing it with
   `list_workflows` surfaces earlier or invalid references.
4. `get_item` returns the complete contract of a single affected object.
5. `describe_system` shows operation and integrity: secrets, locked MCPs, active
   sessions, and invalid references.
6. Keel AI computes the minimum impact, reuses what exists, and mutates in
   dependency order.
7. It reads each object again and re-checks integrity. A "created" response is
   not enough if the set was left incomplete.

Read tools add no bubbles to the thread. Mutations do leave a visible note at the
moment they happen.

Before each tool, the server waits for the typed catalogs to finish loading. The
application's first turn cannot receive a partial list nor write over an empty
snapshot while persistence initializes.

## Complete reads

`get_item` exposes everything that affects execution:

- agent: ID, role, prompt, provider, model, effort, skills, rules, hooks, tools,
  MCPs, knowledge, and builder permission;
- workflow: intent, type, owner, per-turn and preflight skills, rules, knowledge,
  gates, limits, `buildsRoadmap`, and every capability with instruction,
  dependencies, activation, and independence;
- project: members with their effective engine, workflows, active workflow,
  rules, hooks, knowledge, sessions, engine overrides, and per-node assignments;
- hook: event, matcher, body, timeout, guaranteed rules, scope, and state.

The inspector flags dangling IDs, nonexistent requirements, nodes that no longer
belong to the workflow, and assignments to absent profiles.

`list_catalog(kind: "workflows")` remains the quick index of names. To analyze
the whole set, `list_workflows` is used; to edit a particular one, `get_item`.
Keel AI also has `create_workflow` and `update_workflow`, so reading, creating,
and modifying are explicit, verifiable contracts.

To answer which projects still use an earlier configuration, Keel AI reads
`list_projects` and `list_workflows` in the same transaction. It does not need to
walk each name by hand or inspect persisted JSON.

## Adaptive construction

A workflow declares capabilities, not a positional chain. Each capability has a
stable ID, a title, an instruction, a role, dependencies, `required` or
`optional` activation, and an `independent` flag.

- `required` enters the initial graph; `optional` activates only on evidence.
- The owner integrates the case and there is a single writer.
- `independent` demands a different profile from those that produced its
  dependencies. Since CLI sessions are stored per profile, the audit also gets a
  separate context.
- An audit skill is an instruction, not independent evidence.
- Compiler, linter, test, contract, or review create a finding on the affected
  node; repeating the same fingerprint without changes is not progress.

The audit defaults are optional and independent. Keel AI does not add a fixed
roster of planner, diagnoser, implementer, and several auditors: every profile
and node must justify tokens, context, and handoff.

## Available mutations

- `create_or_update_agent` accepts Claude, Codex, OpenRouter, and DeepSeek, plus
  model, effort, skills, rules, hooks, tools, MCPs, and knowledge. Changing
  provider without a model normalizes to the new provider's default.
- `create_workflow` and `update_workflow` write the complete adaptive contract.
- `create_project` and `update_project` administer members, workflows, rules,
  hooks, knowledge, and maintained/read-only mode.
- `update_project(member_engines)` stores provider/model/effort per member and
  project; `node_assignments` stores each capability's concrete agent.
- `unassign_from_agent` can withdraw any of the additive dependencies.

References are validated against the real catalog. Unknown names are rejected or
reported explicitly; they never silently stand as though they were injected.

## Declarative fallback

The fenced blocks exist only if the actions MCP is absent. Their capability
representation is:

```text
id|title|role|required|dependency-a+dependency-b|shared|instruction
id|title|role|optional|implementation|independent|audit the evidence
```

The earlier six-field form is rejected: the persisted domain and Keel AI's inputs
contain no linear APIs, shims, or deprecated code.
