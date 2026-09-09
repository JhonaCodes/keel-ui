# F17 — A session's work plan

## Problem it solves

A session showed `3/7`: which step of the workflow it is on. That says **who is
next**, not **what is left of what was agreed**. The plan the planner writes
during its step lived as just another message in the thread: ten turns later it is
buried, and there is nowhere to look at it again nor any way to know what was
fulfilled.

They are two different axes, and that is why both are now visible. A half-fulfilled
plan with the workflow on step 5 is information neither of them yields separately.

## The model

`StationTask.plan`: a list of `TaskPlanItem` (id, text, done, who marked it). It is
persisted with the session, in its same record.

`setTaskPlan` replaces the plan **while preserving the state of the items whose
text did not change**: replanning midway cannot unmark what is already done. The
comparison is NORMALIZED (`normalizeForMatch`: lowercased, accents stripped,
whitespace collapsed, trailing punctuation removed) — demanding the EXACT text
turned a wording tweak into an unmark, and the cycle went back to redoing what was
already done. `complete_plan_items` compares the same way.

## How an agent writes it

A local MCP server (`keel-plan`) mounted on **every** project turn, without
depending on the profile having tools assigned: the plan belongs to the channel,
not to the agent. The route carries project, session, and profile, so a turn can
only touch the plan of the session it runs in.

| Tool | When |
|---|---|
| `set_task_plan(items)` | When the session has no plan. Concrete, verifiable items, not the workflow's stages. |
| `complete_plan_items(items)` | On closing the turn, with the exact text (or the id) of what that step resolved. |

**The turn carries the plan written out, not just the tools.** Naming them was not
enough, for two reasons seen in use:

- `complete_plan_items` asks for "the exact text" of items the agent had never seen
  — there was no way to read the plan.
- "if your step is planning" was an interpretation, and step 1 of `tdd` is called
  **Charter**: the planner did not consider itself addressed and the session ran
  entirely without a plan.

Now the turn brings the plan rendered with its state (`[x]` / `[ ]`), and the rule
is mechanical: **if the session has no plan, whoever is speaking writes it,
whatever their step**. A consultation turn sees the plan as context but neither
writes nor marks it — it answers and leaves.

`complete_plan_items` accepts **text or id**: the model has both in view, and
demanding the id would turn a correct answer into a silent failure. What it does
not find comes back named in the response, so it is corrected on the next turn
instead of being discovered when the plan does not advance.

A **codex** agent does not have the tools (it receives no MCP servers), but the
plan is no longer foreign to it: it writes it with a ```` ```plan ```` block
(`puntos:` with `text | role` lines) and marks with ```` ```cumplido ````, which
the app parses when closing its turn — the same pattern as ```` ```agente ````. And
since codex only receives a system prompt on the first turn of its session, on
resumed turns the live PLAN section travels prepended to the request, so it does
not work against a plan frozen at turn 1 (see F6).

A CONSULTATION turn does not carry the plan's tools either — not merely the
instruction: the tool is absent. The consulted agent sees the plan as context and
whoever executes the step is who marks it.

## Saying no costs the same as saying yes

The bar offering the next item had **one button**: *Continue*. An item that no
longer applies — because the request changed, or because it turned out to be
somebody else's work — left the session unable to ever close: the only ways out
were doing it anyway, or marking it fulfilled and lying to the thread.

Next to *Continue* there is now **Not doing it**, and a discarded item is a **third
state**, not a merciful `done`:

| | Counts as done | Still pending | Stays written |
|---|---|---|---|
| fulfilled | yes | no | yes |
| **discarded** | **no** | **no** | **yes** |
| deleted (the ×) | no | no | **no** |

The difference from deleting it is what matters: that SOMEBODY decided not to do
something is often the most important part of the plan, and a session read a month
later has to be able to distinguish "it was done" from "it was decided against".

The consequences all point the same way:

- Closing looks at what is **pending**, not at what is unfulfilled, so the session
  closes with discarded items inside.
- The turn's plan shows it as `[-]` and the header says how many the user
  discarded. Without that mark the agent reads it as pending and goes off to do it,
  which is exactly what was just decided against.
- `complete_plan_items` **cannot resurrect it**: it counts it as found — that is
  not an agent error — and leaves it discarded. The decision is the user's and is
  not erased from behind.
- In the sidebar list it is struck through with its own icon, and **tapping it puts
  it back on the table** — returning is not fulfilling, so it comes back pending.

## One plan item = one lap of the workflow

The flow was **a single pass**. With a seven-item plan, step 1 planned the first
one, the implementation did that one, and on reaching the last step there was no
way to go back and plan the remaining six. What the channel showed was this:

> **rust-expert**: I am not implementing without the charters for the remaining
> items — that is step 1.
> **planner**: correct, the charter is my step, not this consultation.

Both were right and the session did not advance. It was not the planner's prompt
and no agent was missing: the lap was missing.

Now, with pending items and the session stopped, **"continue" starts another full
cycle from step 1, scoped to the next item**. It exists as a written word in the
channel and as a bar pinned **above the composer**, saying which item is next and
which role's turn it is.

That bar used to live at the bottom of the sidebar, below the item list, and nobody
found it there: the sidebar is the CONTEXT column, and an action hidden at the end
of the context is an action that does not exist. Actions are looked for where you
are typing. Only if the message is short and says nothing else: *"continue but look
at endpoint X first"* is a message for whoever has the floor, not a new cycle.

The words have two levels. **"Continue"** (and an explicit "go on with the next
item") always counts — it is the word the button and the closing message teach.
**A bare "go" / "next" / "ok"** counts only when the last thing in the thread is
the closing invitation: at any other moment, answering "go" to an agent's question
is an answer to that agent — it used to launch a whole cycle by accident.

The cycle carries **the session's original request** (stored in
`StationTask.request` on the first run — without that, a member joining only in
cycle 3 never knew what had been asked) plus the item as its only work, and tells
the flow to continue on the same branch and the same PR without starting over (the
complete delivery contract lives in the DELIVERY section of the prompt, see F19).

Two more mechanics of the cycle:

- **Handoff between steps**: the thread never travels to the CLI, so step N
  receives "what @previous left stated on closing step N-1" (the real result of its
  turn, trimmed), and each step closes by saying in two lines what it leaves ready.
  Step N used to see NOTHING of N-1.
- **A step that fails cuts the cycle** and the session is left as not finished, with
  the invitation to fix and resume. The flow used to march through all N steps
  failing in a chain over a dead turn.

## Whose item is whose

`set_task_plan` accepts `{text, role}`. The **role**, not the handle — just like the
workflow's steps, so the same plan serves in the Rust project and in the Flutter
one, where that role is filled by another agent. It shows in the sidebar under each
item and travels in the turn as `[ ] (implementer) …`.

That is the "who does what": the planner's work, not a new agent's.

## Closing is decided against the plan, not against the steps

A workflow can walk all seven of its steps and leave half of what was agreed
undone, and until now that was sealed as "finished": the counter said 7/7 and
nobody looked at the plan. *The flow ended* is not *the session is done*.

Now, when the last step closes:

- **Plan complete** → session finished.
- **Items remain** → it goes back **once** to the verifier (the first step's owner;
  if that role is vacant, the last one's; between the two, the one not running on
  codex is preferred, since it has the real plan tools) with the exact list of what
  is pending. Its job there is to verify **against the code**, not against what was
  said in the thread: mark what is actually done, remove from the plan whatever
  stopped applying and explain why, and leave genuinely missing items unmarked
  while saying which role they fall to. It does not implement: it verifies.
- **If something is still missing after that** → the session is NOT left finished,
  and the closing message names what is missing.

That turn runs with consultations closed. Closing is not reopening the work: if the
verifier drags the others in, the session runs all over again through the back
door.

A session with no plan has nothing to verify and closes as always — another reason
the plan is written on the first turn no matter what. With one honest exception: if
the cycle ended **with no plan and without producing a single work message**, the
session is left as NOT finished — "it ended with nothing" cannot be sealed the same
as "everything fulfilled".

## In the UI — two views, not one

**In the thread** what was agreed stays written, to be read whole:

```
🤖 WORK PLAN · 6 items
   ○  Pure aggregation function with expected/variance
   ○  RED test that fails against the declared oracle
   …
```

and each time a step closes items, its acknowledgment:

```
🤖 PLAN · 3 of 6
   ✓  RED test that fails against the declared oracle
```

Replanning does not overwrite the previous one: it writes another block, marked
`PLAN REPLANNED`, and the conversation keeps both versions. The per-step
acknowledgment exists so that "it says it did it but did not tick it" is visible at
the moment and not three turns later.

**In the sidebar** lives the LIVE plan, which is the other question: what is left
now.

Beneath the open session, in the sidebar. Only the open one: with four sessions in
the project, four unfolded plans turn the column into a wall.

- `✓` fulfilled (struck through), `▸` the first pending one (what is being done),
  `○` what is left.
- Clicking an item un/marks it by hand: the final verdict is the user's.
- The × for removing an item appears under the mouse — twelve permanent ×s are
  noise.
