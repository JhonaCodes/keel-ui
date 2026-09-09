# F25 — A project's status

## Problem it solves

The roadmap (F23) was read over MCP, for an agent. You had no screen at all:
**there was not a single progress calculation anywhere in the app**. To know how a
project was going you had to open the folder and count `.md` files by hand, and to
know who was on what, look at four sessions one by one.

And there is a question neither of those answers separately: *which roadmap task
is which agent working on, and in which of my sessions?*

## What it is

The first of a project's three sections — Status, Boards, Sessions — at the top and
with no list beneath: there are no statuses, there is one. Sessions come and go;
how the project is going is always there.

That the status was being looked at **was inferred** from there being no open
session, and while the project had two things inside, that was enough. With boards
it stopped being enough: "no session open" became three different situations. It is
now an explicit lens, one of six, and who holds it is in
[F32](32-single-navigation.md).

**It looks, it does not touch.** There is not a single control inside, and that is a
decision: to open a session there is its row in the sidebar, ten pixels away. A
screen that informs and also acts ends up being two bad screens.

## Where the numbers come from

From crossing three things that until now were crossed nowhere:

| What | Where it lives | Who writes it |
|---|---|---|
| The tasks and their state | The repo, in `TASKS/` | The agents, on closing |
| Who holds each one | The local database | The claim, atomic |
| The live sessions | The local database | The running turn |

`buildProjectRadar` is a **pure** function: data in, the view's model out. It is
the only part of this screen that can be tested without the whole app.

**The claim beats the file.** A task with `estado: libre` and somebody working on
it counts as in progress, because the `.md` is marked when the turn closes: until
then it would say nobody is doing it precisely while somebody is.

Drafts are counted separately and **do not enter the total**. They are not a
promise yet, and including them sinks the percentage without anybody having failed.

## The five blocks

- **Compliance** — `14 of 31 · 45%` and a four-segment bar.
- **In progress now** — for each live claim: the task, the agent with its channel
  color, **which session it runs in**, how long ago, and how much the claim has
  left. Ordered by whichever expires first, which is the only actionable thing.
- **Sessions on the radar** — all of them, with their step, their plan, their cost,
  and which roadmap task they have claimed.
- **Stuck** — open blockers and **broken references**. This is the first time that
  is visible on screen: the reader already detected them, but they only surfaced in
  `claim_task`'s error, once somebody had already run into them.
- **Requirements** — two counters pointing at F26.

## When it is re-read

`readRoadmap()` deliberately does not cache (F23) and walking a directory is
cheap. It is re-read when a claim changes and when a turn closes — the two moments
the numbers actually move — and every 15 s as a floor, which exists for what
happens OUTSIDE the app: a `git pull`, another agent marking `estado: hecho` from
another machine.

## When the repo does not have the format yet

A zero says nothing: it does not distinguish "it has not started" from "it is
written wrong", and those are two problems with two different ways out.

So with no format the screen does not show zeros: it shows **what is missing, line
by line**, with the file, and offers one single thing: opening the session that
fixes it. `checkRoadmapFormat()` checks seven things — the folder at the root, its
README, the groups with theirs, no loose task, the frontmatters, zero broken
references — and returns concrete findings, not a boolean.

That session starts with the diagnosis already inside the request and with a
reserved skill, `keel-formato-de-tareas`, carrying the whole specification and the
templates inlined: the agent does not depend on reading our repo.

**The button opens the session AND takes you there.** It used to only create it: it
was left in the sidebar and you kept looking at the same error screen, with no
signal that anything had happened. Creating is not going — that rule holds for what
starts on its own, not for what you pressed — so the button is what navigates.

And while that session stays open, the button **stops offering to open another**:
it says *go to the open session*, or *it is working* if a turn is in flight. Two
sessions fixing the same folder step on each other's files, and the second would
start with a diagnosis the first is changing underneath it. The rule lives in the
ViewModel and not in the button: asking for the session twice returns the same one.
One left in `failed` **counts as open** — that is the verdict of "fix that and close
again", not one to discard.

### The agent has to be able to check it while building it

`check_roadmap_format` is a turn tool, and it exists because of a mistake seen in
use: the check lived ONLY at closing, so whoever was building the format worked
blind. They went looking for a `keel` command in the terminal — which does not
exist, we uninstalled it — and ended up reading the `referencias_rotas` field of
`list_roadmap_tasks` as though it were the complete check. It is one of the seven
things it looks at, not the other six.

Two corrections came out of that:

- The tool returns exactly what closing decides, so you can iterate until it goes
  green instead of closing to see what happens.
- The format skill now says, in so many words, that there is no `keel` command and
  that `list_roadmap_tasks` is not the checker.

### A consultation turn also receives the roadmap

It used to not, and the effect was the worst possible one: **the auditor — who
almost always speaks as a consultation — saw "keel-roadmap disconnected" precisely
when asked to verify the roadmap**, and answered the only honest thing it could,
that it had nothing to do it with. It now receives it in READ mode: it can list and
check, it cannot claim or release tasks. Claiming belongs to whoever executes the
step; a consulted agent answers and leaves.

The mode comes from the URL (`/roadmap/<project>/<session>/<profile>/consulta`),
not from an argument: a consultation turn has no way to claim it is a step.

### The check on closing cannot be skipped

Asking an agent to verify its own work through the prompt is asking, not
guaranteeing — the same distinction that separates a rule from a hook (F22).

When that session closes, keel-ui runs `checkRoadmapFormat()` **on its own** and
publishes the result in the thread, with the whole list: what passed and what did
not. If anything fails, **the session is not left finished** and what failed becomes
the next request.

It lives in `_finishSession`, which is the only place ALL closures pass through. A
verification that can be bypassed through another branch is not a verification.

And there is nothing to "import" afterward: the reader reads the folder fresh every
time, so as soon as the check passes, the status starts working on its own.

## Verification

1. A repo with `TASKS/`: the percentage matches counting the `.md` files by hand.
2. A claimed task appears with its agent **and its session**.
3. A task with `estado: libre` and a live claim counts as in progress.
4. A broken reference appears in "Stuck" with the file and the reason.
5. With no format, the screen says what is missing and shows no zeros.
6. "Define the format" opens the session with the diagnosis in the request.
7. That session closes with a broken reference → it is NOT left finished, and the
   thread carries the list.
8. Fix it and close again → finished, and the status is already reading.
