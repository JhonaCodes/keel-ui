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

Consultation branches are reconstructed in dependency passes so replayed
answers do not disappear when their parent appears later in the history.
Timestamps order the question and answer evidence; missing parents and cycles
cannot keep reconstruction running indefinitely.

Each node's delegation count includes its direct native subagents and expert
consultations, including an active consultation before its answer arrives.
Repeated answers from the same expert remain one branch. The count is local:
a developer's native auditor and a planner's consultation to that same expert
are separate branches, and the auditor's own expert consultations belong to
the auditor.

Regression coverage includes reordered history, persistence round-trip, a
native delegation alongside two nested expert consultations, parent edges,
depth and counts. Validation: 191 map/project/prompt/workflow tests passed,
one separately gated process test skipped; affected-file analysis and macOS
debug compilation passed.

Background launch acknowledgements are not child results. The Claude adapter
also recognizes the implicit async launch response and correlates its agent ID
with the original tool invocation, so the later task notification closes the
same child. Text blocks are decoded before display rather than shown as JSON.

If the parent stream closes without a child's terminal notification, the child
becomes `unconfirmed`, not `failed`. Reloading unfinished history uses the same
state. Chat and map inspection label it as an unconfirmed result; there is no
claim that the external process is still running. Explicit failures remain
failures. Previously saved failures are not guessed into successes.

Idle and duration watchdog limits default to zero (disabled). Positive limits
saved on existing workflows still apply. Both the form and MCP policy updates
accept zero, and the form explains that zero means unlimited.

Validation includes a process fixture with a completed child, an explicitly
failed child and a child without a completion notification, plus a virtual
three-day idle interval with disabled watchdogs. The area regression passed
194 tests; the separately invoked process integration passed as well.

The chat distinguishes an open turn awaiting provider output from received
reasoning. Missing reasoning is no longer presented as proof that a model does
not expose reasoning. An explicit progress indicator denotes an open turn,
not verified external process health. Tool events retain their specific
activity widget, and incoming text switches to writing before file collection.
Stopped sessions and sessions awaiting a user decision hide the live strip.
The widget transition test and area regression pass (195 tests).
