# F35 — The failure log

## Problem it solves

The app knew perfectly well when something broke. It said so forty-four times:

```dart
Log.e('System vault operation failed', error: error);
Log.e('Knowledge sync failed for ${base.name}', error: error);
Log.e('Workflow run failed', error: error);
```

And it said so **in the console**, which exists only if you launched Keel from a
terminal and still have it open. A backup that could not write, an index left
half-done, or a flow that got cut at three in the morning left no trace anywhere
you could open later. The typical symptom: "the backup says it is up to date" —
because `lastBackupAt` reads the old zip's date — while the one that failed was
carried off by the scrollback.

## One door, three sources

The important part of the design is not the list: it is **where it hooks in**.
Nobody had to go modify forty-four call sites, and nobody will have to remember
number forty-five.

| Where it comes from | How it gets in |
|---|---|
| `Log.e` / `Log.f` in any file | the `Logger.root` listener |
| A build, layout, or paint error | `FlutterError.onError` |
| An async exception with no owner | `PlatformDispatcher.onError` |

`logger_rs` publishes everything to `Logger.root` — from `package:logging` — so a
single listener covers every `Log.e` call that exists today, that gets written
tomorrow, or that comes from a third-party package.

The three sources **do not replace what the app already did**: Flutter's handler
is chained with the one that was there, so the console's red banner and the grey
box on screen still appear as before. The console is useful while you are looking
at it; the log is useful for all the rest of the time.

## What gets stored

```
The flow was cut in "northstar-web" · Migrate the cart
3 min ago  ·  projects_viewmodel.dart:1412                        ×2
```

One line readable without opening anything, and the whole stack inside. The
origin — `projects_viewmodel.dart:1412` — comes from the stack's first Keel
frame, with the log's own frames skipped: without that, every failure would say
it came from here.

The stack almost never arrives in a `Log.e` (most calls pass `error:` and nothing
else). When the error is a Dart `Error`, its own is used, which carries the same
information.

A project's flow got the project's and the session's name added **in the
message**, not as separate fields: `Workflow run failed` at three in the morning
does not say which of the six projects it was.

## What it does NOT do

**It sends nothing out.** Keel has no server and no account, and a failure
uploaded somewhere is a failure travelling with your projects' paths, your repos'
names, and sometimes a piece of your code inside. The log lives in the same local
database as everything else.

It does not carry project or session ids either: storing the id invites a button
that navigates, and for that the log would have to know about projects and
navigation — which already know about it. The name in the message gives the same
answer without the cycle.

## Keeping it from eating the app

A system that captures errors and can amplify them is worse than having none. The
three possible loops, and how each is cut:

| The loop | What cuts it |
|---|---|
| Writing the failure fails → `LocalDatabase` reports it via `Log.e` → writing the failure fails | The first failed write **turns persistence off for good**. The log continues in memory until you restart. |
| A layout error fails once **per frame** → publishing redraws → it fails again | The repeat does not publish: it increments the counter silently and reports at most once per second. |
| Publishing redraws → the redraw blows up → it re-enters to record | A synchronous guard: one lap and it stops. |

And two caps: **200 failures** or **30 days**, whichever comes first. The cap
matters more than the window, because two bugs alternating do not coalesce and
would fill the list in seconds.

## The notice

A new entry on the rail, with the count of the ones you have not looked at:

```
  ⚠ ③
Failures
```

It is the only one on the rail that opens **because it lit up** and not because
you went looking for it. Opening the panel marks them seen — looking at them IS
seeing them, and additionally asking for a click on "got it" is asking twice for
the same thing. A failure repeating marks it unseen again, because having already
read it says nothing about whether it is still happening.

If the window is **not focused**, a macOS notification also goes out. With Keel in
front, the red dot is enough: you are already here. What the red dot cannot do is
tell you while the flow runs for twenty minutes and you are on something else,
which is exactly when a failure gets lost.

It goes out through `osascript` and not a new package — the app already talks to
macOS this way (`which`, `sysctl`, `ps`). The cost is that macOS attributes the
bubble to Script Editor, and if you never granted it notification permission, it
does not appear. That is why the red dot is the real notice and this is the extra.
At most one every two minutes, with a five-second cap: an `osascript` left waiting
for something must not hold on to the notice that something else failed. In a test
run it never fires.

## Where it lives

| What | Where |
|---|---|
| Model, state, and repository | `integrations/fault_journal/src/fault.dart` |
| The three sources | `integrations/fault_journal/src/fault_capture.dart` |
| The macOS notification | `integrations/fault_journal/src/fault_notice.dart` |
| The panel | `integrations/fault_journal/src/ui/faults_panel.dart` |
| The rail entry | `modules/agents/ui/view/agent_rail.dart` |

It installs in `main`, **after** the database and before everything else: a log
that starts with nowhere to store turns itself off on the first attempt. Main
window only — sub-windows are another engine with no database to write to.
