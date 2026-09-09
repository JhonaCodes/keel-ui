# F50 — A requirement says what the target project is doing

## Problem it solves

Whoever opened a requirement toward another project saw "taken" and nothing
else. There was no way to tell whether the other side had an agent working, one
waiting on the user, or nobody at all: the session that took the requirement
(`takenInSessionId`) existed in the model but was never consulted to say so.

## Decision

`requirementTargetActivity(Session?)`
(`modules/requirements/service/requirement_target_activity.dart`) summarizes
that session's state in one sentence: "working (thinking | writing | working |
between turns)", "waiting on you: there is a pending decision" (F44), "finished
its session", "its session failed or was stopped", "no live turn right now".
Null when there is no session.

The requirement thread header shows "target: …" in the target's color, below the
origin → target line. It is derived from the live state of projects, so it
changes on its own while the other side works.

## How to verify it

- `test/requirements/requirement_thread_view_test.dart`: the sentence for each
  session state, and the header saying "working" when a target session is
  running.
