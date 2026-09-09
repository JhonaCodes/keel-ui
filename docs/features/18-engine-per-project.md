# F18 — A member's engine, per project

## Problem it solves

An agent is registered once and reused everywhere: that is the rule, and it is
the right one for its identity — handle, role, instructions, skills. But the
model is not identity, it is cost. `@nova-builder` doing the GREEN step of a
small fix and `@nova-builder` redesigning a screen are the same person
thinking differently, and until now they were the same configuration: changing
its model on its card changed it across all six projects.

The practical consequence was choosing wrong in both directions — paying for
Opus on maintenance, or falling short on the redesign — with nowhere to look at
it: the panel said who did each step, never with what.

## The model

`Station.memberTuning`: a map `profileId → MemberTuning`, where `MemberTuning`
carries `provider`, `model`, and `effort`, **each one nullable**. Null means
"whatever the profile says", not a default value copied in — an agent whose
model is raised on its card inherits that in every project that has not pinned
it.

A tuning with all three fields null is deleted instead of saved: an empty
override would show as marked in the UI while changing nothing.

`station.tuned(member)` returns the whole profile with the engine applied. The
turn resolves it **once**, at the start, and sends that from then on — the
provider included, because changing it changes what surface the turn has: a
member switched to codex loses tools, MCPs, and the plan, exactly like an agent
that was codex from birth.

Changing provider without picking a model does not drag the previous one's
alias along: the two CLIs do not share a single model name, so `sonnet` on codex
is a startup failure, not a degradation. In that case it falls back to the new
provider's default model.

## In the UI

Under the name of each step's owner, in the workflow panel: `Opus 5 · High`. It
is in plain sight rather than behind a tooltip because it is the line that
explains cost — a step on Opus is worth several times one on Sonnet, and that
does not show until the invoice arrives.

An accent-colored dot in front marks it as a tuning of this project; with no
dot, it is the engine from its card. Clicking opens the side panel with
provider, model, and effort, each with its "the agent's own" option, and a line
stating the result. For codex, effort is disabled: its own config resolves it,
so offering it would promise something the turn never sends.

The tuning belongs to the MEMBER in the project, not to the step. If
`nova-builder` has three steps, all three change together: the same agent
thinking differently depending on the step is a distinction nobody can hold in
their head.

The change takes effect on the following turn. The one running finishes with the
engine it started with — the CLI has already been invoked.

## Export

Tunings travel in the project's file (`memberEngines`), by handle and not by id,
like everything else in the mirror. A tuning for a profile that no longer exists
is not written, and on import it is applied only if the handle exists on this
side: without that, moving machines silently lost half the cost decision.
