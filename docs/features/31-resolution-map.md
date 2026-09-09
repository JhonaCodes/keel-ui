# F31 — Resolution map

A session's map renders the persisted `ResolutionCase` as a directed graph. Its
trunk holds exclusively the workflow's `WorkNode`s, from the request through to
closure. The project's other members are not drawn as potential stages: they
appear only once they took part in a consultation. Each work node shows owner,
state, evidence, and dependencies.

Prepared nodes with the same dependencies may appear in parallel. A solid edge
means satisfied evidence, a faint one a dependency still pending, and a finding
returns only the affected node to reformulation.

Every `WorkNode` has its own tree underneath. A consultation to another agent
is born from the node that raised it, and a chained consultation from the
previous consultation. Subagents appear beneath the turn that opened them, be
that the main work or a consultation. The inspector keeps the request, the
activity, the result, and the synthesis. They are permitted only for research,
inventory, or verification; they do not write the workspace.

The view keeps the navigable canvas, zoom, active-node following, and the
mockup's inspection cards. Visible content is built from `ResolutionCase.nodes`,
`Finding`, and `Evidence`, so a validated node is never redrawn as pending work
because of a global restart.
