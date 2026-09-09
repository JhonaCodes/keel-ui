# F7 — Economical communication between agents + cost ledger

## The addressing contract (already structural, now documented)

- **Identity**: the profile's handle (`@name`) is unique across the whole app.
- **Scope**: a mention only resolves against the MEMBERS of that session's
  project (`membersOf`) — a handle from another project or a loose agent never
  receives the turn. Each member also has its OWN CLI session per session
  (`sessionsByProfileId`), so the effective address is
  `handle + session + project/session` and two projects cannot collide.
- **Zero-cost coordination**: mention routing is DETERMINISTIC (regex plus the
  member table in `_resolveConsultations`), local, and never passes through a
  model — there is no "LLM orchestrator" charging tokens to decide who speaks.
  The only thing that costs tokens is the real work turns (1 mention = the
  consulted agent's turn plus the asker's continuation).
- **Code is not prose**: an `@handle` inside a code block or span is not a
  mention — the scan runs over the text with code stripped (`stripCodeSpans`). A
  diff with a handle in a comment no longer fires turns.

## Cost brakes

- `_maxConsultDepth = 3`, one asker→asked pair per turn, and the asker's
  continuation cannot open new consultations (courtesy ping-pong does not exist).
- **Budget per root turn**: `_maxConsultsPerRootTurn = 5`, counting the whole
  chain. Depth does not bound WIDTH — with five members mentioning each other, a
  turn could fire dozens of CLI turns. At the cap, the remaining mentions fire
  nothing and the thread says so.
- **The inverse pair does not bounce**: if A already consulted B in this turn,
  B's mention of A is ignored — the answer comes back on its own through the
  continuation. A→B→A dies there.
- Companions prompt: "never out of courtesy, always out of specialty".
- Leak fix: `_consultedPairs` (keyed by turnId, which never repeats) is purged
  when no session is left running.

## What the consulted agent receives (minimum context, now mechanical)

The prompt used to ask for "just the question" while the code sent the asker's
ENTIRE turn. Now the EXCERPT travels: the paragraphs that mention the handle plus
the immediately preceding one (`_consultExcerpt`, capped at ~4k, falling back to
the full text). The companions prompt states it plainly: "the question goes in the
mention's paragraph — whatever is not there, the consulted agent does not see".

The consulted agent also receives the cycle's MECHANICS: which step it is on,
which steps are ITS OWN (resolved with the flow's same role/handle semantics),
and the rule in three cases — future steps: do not get ahead; a step that already
passed and is missing something of yours: resolve it HERE (that step does not come
back); a decision in your area: take it now. "Do not get ahead" and "resolve it
here" used to be undecidable: the consulted agent had no way of knowing whether
its step had already passed.

And the answer that returns to the asker is WHAT THE CONSULTED AGENT SAID (the
real result of its turn), not the thread's last message — which could be an error
or a system notice dressed up as an answer. If the consultation fails or comes
back empty, the continuation does not run and the thread says so.

A consultation turn runs WITHOUT the plan's tools: it sees the plan as context,
and whoever executes the step is who marks it.

## Mentioning is not handing over the work

A step that ends by saying "it now falls to @nova-builder to take the RED" is
not closing: it is **opening a consultation**. The mentioned agent runs right
there, inside the step of whoever named it, and does the next step's work without
the workflow advancing — the board reads "step 1 of 7, Charter" while the RED is
already written, and there is no way to tell where the session is.

The turn says it explicitly: whoever comes later is not mentioned to hand work
over; the workflow gives them the floor when the step ends.

**The tiebreaker** — the frequent case where the specialist IS the owner of the
next step, which used to sit between two colliding rules ("always defer by
specialty" vs "never mention the next step's owner") — is a single question: can
your step close without their answer? If yes, do not mention them — say what you
are leaving ready and close. If no, consult them with only the question you are
missing.

## The economics of cycles (since F17)

One plan item = one full lap of the workflow: a 6-item plan in a 7-step flow is
up to 42 work turns, plus consultations. That is why the prompt insists an item is
a DELIVERABLE UNIT and not a half-hour session — the item's size is the cost
multiplier. And that is why a step that fails cuts the cycle instead of dragging
the error through the remaining steps.

## The ledger stays, but is no longer shown

- `Session.costUsd` + `costByProfileId`: accumulated from each turn, persisted
  with the session, and exposed in the local API (F12).
- **The UI no longer shows money.** It was in the footer of every bubble, in the
  session header, and in a column of the project's status, and it changed no
  decision anyone made while looking at those screens: when you want to know
  whether a turn was expensive, what you look at is the model and the effort
  (F18), not the number after the fact.
- What took that place is the thing that does decide something: **context**. A
  session at 90% is about to run out of air; the header states the percentage, and
  its tooltip the tokens against the model's ceiling. In each message's footer
  only how long it took remains.
- Known limitation: codex turns report cost 0 (its JSONL does not emit it).

## And the ledger that really is a series

The above is a per-session accumulation: how much THIS channel has spent. It is
good for that and nothing more — you cannot ask "how much did I spend on
Tuesday", because each turn's datum was summed and discarded.

[F30](30-machine.md) adds the per-turn record that was missing, with the four
token counters and the model. The two coexist: the session's accumulation belongs
to the channel and travels with it; the ledger belongs to the machine and is
pruned to ninety days.
