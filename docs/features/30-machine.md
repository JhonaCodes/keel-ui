# F30 — Machine: services, consumption, and hardware

## Problem it solves

Three questions that until now were answered outside the app: which CLIs do I
have installed (a terminal), how much have I consumed (a web dashboard), and why
is the machine slow (Activity Monitor).

All three are about the same thing — what Keel is doing on this machine — so they
go together.

## First: stop throwing tokens away

The CLI reports each turn's counters in its `result` event. The app read them,
summed them for the context percentage, and **discarded them**. That is a
thermometer of the moment; it was never a series.

Which is why it has to be said where it gets read: **the history starts the day
this is installed**. No chart can show what came before, and an unexplained gap
looks like a bug.

`lib/src/integrations/usage_ledger/` stores one record per turn — when, engine,
model, profile, project, session, the four counters, duration, and cost — and
prunes it to ninety days. It is **append-only**: it writes one key per turn
instead of rewriting the whole list, which is what `replaceAllWithPrefix` would do
on every message.

### Codex is recorded too, at zero

Its CLI reports nothing (`codex_cli_service.dart` fixes cost and duration at 0 and
emits no context). That is **not the same** as not having spent anything.

Without the row, the screen would say codex never ran. With the row at zero, it
would say it was free. It is recorded, and the rollup marks it as *unmeasured*.

### A duplication that went away

Reading the `result` event was written word for word in two places:
`ClaudeCliService` and the task runner's isolate, which builds maps instead of
objects because they have to cross the isolate boundary.

What they shared was not the shape but the READING. That now lives in
`core/services/turn_usage.dart`, pure and tested, and both use it.

Something worth stating was written down there too: occupied context is input plus
cache, **without the output**, because what fills the window is what goes in, and
what was generated is already counted inside the next turn's input.

## What is installed

`which` plus `--version` over a known list, in parallel, cached for ten minutes:
a CLI does not get installed while you are looking at the screen.

Claude and codex are marked **supported**. Any other one that shows up —
opencode, gemini, cursor-agent, amp, aider, ollama — is listed as **detected, no
adapter**. It is more honest than pretending they do not exist, and that list is
incidentally the list of what is missing.

Detecting is not integrating: none of those gets to run a turn.

## The hardware

`sysctl` for the chip, the cores, and the load; `vm_stat` for memory; `ps` for
processes.

Occupied memory is **not** "total minus free". On macOS, inactive memory and the
file cache are returned when they are needed, so counting them would give 95%
always and say nothing. What is really occupied is active + wired + compressed,
which is the same thing Activity Monitor shows.

It samples every 3 seconds **only while the screen is open**. A timer running
forever to draw a number nobody is looking at is exactly the kind of thing that
made the app take twenty seconds to become responsive (F27).

### On whose behalf each process runs

`ps` knows the pid and the command but not the reason, and the reason is the only
thing that makes the list useful: "claude at 78% CPU" says nothing; "claude at
78%, for the bid session that comes back at zero" does.

`RunningProcesses` is a pid → label table filled when each turn starts and
cleared when it ends. Project turns run in another isolate, so their pid arrives
**as a number in a message**: a `Process` does not cross an isolate boundary, and
on the other side only the number is needed.

## The chart

A `CustomPainter` of our own rather than a charts package. The repo already draws
by hand (`SessionGraphPainter`), it is fourteen bars, and a charting dependency
for this would bring a hundred widgets nobody else will use.

Days with no activity are drawn anyway, as a flat line: a gap on the axis says
something, and skipping it would lie about the rhythm. Each model's color comes
from its name and not from its position, so if you did not use opus one day the
rest do not change color.

## What this screen cannot say

**Consumption is Keel's, not your account's.** The app can only sum what went out
through here; what you spent in a separate terminal it does not see, and promising
otherwise would be inventing a number.

**The hardware part is macOS.** `sysctl` and `vm_stat` do not exist elsewhere.
Since the app is macOS-only today it is not a limitation yet, but it is a debt
written down.

## Verification

1. Open Machine: claude and codex detected, with version and path.
2. An installed CLI that Keel does not support appears as *detected, no adapter*;
   one that is absent, as *not installed*.
3. Run a turn and come back: that day adds to the chart.
4. A codex turn appears in the table as *unmeasured*, never as zero.
5. With a turn running, its process is in the list with whose behalf it runs on.
   When it ends, it disappears.
6. Close the screen: sampling stops.
7. With an empty ledger, the screen explains why instead of showing a blank
   chart.
