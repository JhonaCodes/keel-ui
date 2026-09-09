# F32 — A single navigation

## Problem it solves

With a board open you tap a session: nothing happens. The menu highlighted the
session, the center stayed on the board, and there was no way back except tapping
something else first.

It was not a one-row bug. **What is being looked at was written in four places**
and each one could move without the others:

| Where | What it stored |
|---|---|
| `_focus` inside `AgentsScreen` | agent · project · requirement · board |
| `_openBoardId`, next to it | which board |
| `ProjectsState.selectedProjectId` | which project |
| `Project.activeSessionId` | which session, and whether there was one |

A session's row called `selectSession` directly, which moves the fourth and does
not touch the first. The Status row, the same. A job arriving through the API
opened a session in a project that was not even the one you were looking at. Each
path moved its half and the other stayed where it was.

## What it is

A **lens**: what the center area shows, as a single datum, with a single owner.

```
agent · requirement · projectState · boards · board · session
```

`WorkspaceViewModel` is the only thing that navigates, and each `openX` does the
**two** things that used to be separate: it moves the selection in whichever
ViewModel is concerned and states which lens is left.

```
openSession(project, session)  → selectProject + selectSession + session lens
openProjectState(project)      → showProjectState(...)   + status lens
openBoards(project)            → selectProject(...)      + boards lens
openBoard(board)               →                           board lens
openProject(project)           → selectProject(...)      + wherever you left it
```

The screen stores nothing: it draws what the lens says.

`openSession` selects the **project** as well as the session. `selectSession`
only marks which one is active WITHIN a project, and the center area draws the
selected project's: while everything calling it came from an already-open
project, the difference was invisible. From a requirement — which lives in
another lens and points at the TARGET project — it shows immediately.

## Selecting is not navigating

The ViewModels underneath **do not know the lens exists**, and it stays that way.
That is what lets a job arriving through the API open its session without dragging
you to it: you did not ask to go. The same with a Keel AI tool that creates a
session in another project.

The "New session" button does navigate, because it is a button: the intent is in
the gesture, not in the creation.

## The id does not outlive the lens

`boardId` only exists with the lens on `board`. An id that outlives its lens is
the next desync: a board deleted three screens ago, still pointed at, waiting for
something to draw it.

And for what gets deleted **while** you are looking at it, the view asks before
drawing instead of asking whoever deletes to notify:

```dart
workspace.resolved(boardExists: ...)   // board with no board → boards
```

An agreement of "remember to notify navigation" is honored twice and broken the
third time. Asking does not forget.

## What the change looks like

An open project shows **three sibling sections**, written with the same widget and
therefore read as equals:

```
# atlas-workspace
  ·  Status                    0%
  ▾  Boards                     2
       • Launch offer           ×
       • Test push              ×
  ▾  Sessions                   2
       • New session       1/8  ×
       + New session
```

Status used to be a row, BOARDS a small-caps header, and sessions had no header at
all: three different shapes for three things that are on the same level.

The row navigates; the chevron opens and closes the list. They are two gestures
because they are two things: going to the boards and seeing which ones exist are
not the same. Status carries a dot rather than a chevron — a triangle that opens
nothing is a promise the row does not keep — but it occupies the same place, which
is what keeps the three aligned.

### And the menu got shorter

Two things were inflating it:

- The "no boards yet" text spent four lines of menu saying there was nothing, with
  nothing to press. It moved to the screen, which is where something can be done
  about it.
- Each × claimed **48 points of height** — a finger's measure, in a desktop app —
  and the whole row went from 30 to 54. Six rows with an × were half a screen of
  menu.

## Where it lives

| What | Where |
|---|---|
| The lens, as data | `modules/workspace/model/workspace_lens.dart` |
| The only thing that navigates | `modules/workspace/viewmodel/workspace_viewmodel.dart` |
| The shared section row | `core/ui/sidebar_section_row.dart` |
| The three sections | `modules/projects/ui/view/projects_sidebar.dart` |
| The Boards section | `modules/boards/ui/widget/boards_group.dart` |
| The project's boards screen | `modules/boards/ui/view/project_boards_view.dart` |

## Verification

1. With a board open, tap a session → the session opens.
2. With a board open, tap Status → the status opens.
3. Tap Boards with none → the screen with the two paths.
4. Ask Keel AI for one from there → the window opens with the request made.
5. Delete the board you are looking at → it falls back to the list, not to a gap.
6. Close the only session → the center offers to open another.
7. A job through the API in another project → does **not** move you from where you
   are.

## See also

- [F25](25-project-status.md), which was the inferred lens.
- [F29](29-boards.md), the one that broke the inference.
