# F34 — Working in another worktree, and coming back

## Problem it solves

Sometimes two things from the same repo have to happen at once, and they are
different things: an urgent fix while the big migration is still open. Git
already solves that with `git worktree`: two folders, two branches, one history
and one object store.

What was missing is for **the app to notice**. Without that, three things happen,
all three silently:

1. **Two projects that look like the same one.** `keel-ui` and `keel-ui-mapa` are
   two sidebar entries with similar names and no mark saying the second is an
   offshoot of the first.
2. **The agent does not know where it is.** The DELIVERY section asks it to
   *"create a branch for the session"*. In a worktree the branch ALREADY exists —
   it is the reason the folder exists — and creating another on top splits the
   same work across two branches and two PRs.
3. **A one-line bug.** `usesGit` was resolved with
   `Directory('$dir/.git').existsSync()`, and that failed in two cases: in a
   worktree `.git` is a **file** pointing at the main one, and in a subfolder of
   the repo it is simply absent. In both, the answer was `false`, and the agent
   did not receive the delivery section. The part telling it to open the PR,
   precisely there, never arrived. The question is now answered by git, which is
   right in all three cases.

And when the parallel work ends, there is a move that is always done the same way
and always by hand: bring the branch to the main worktree and delete the folder
next door.

## Nothing to configure

There is no "this is a worktree" checkbox. It is detected, or it is not.

A single read, which writes nothing:

```
git -C <dir> rev-parse --show-toplevel     → THIS copy's root
git -C <dir> worktree list --porcelain     → all of the repo's
```

The **first** in that list is always the main worktree — git guarantees it — and
everything else depends on that. If this root is not the first, you are in one of
the side ones.

`--show-toplevel` also handles asking from a subfolder and returns the canonical
path, with symlinks already resolved: comparing against what the user typed in the
project's form would not work on macOS, where `/var` is a link to `/private/var`.

It is re-read every twenty seconds while a project is open. Not because the
worktree changes — it does not — but because **the branch does**: you change it in
a terminal, or an agent changes it during its turn. The screen is only notified
when the read DIFFERS from the previous one; publishing the same thing every
twenty seconds would be redrawing for nothing.

## The notice

A one-line strip above whatever you are looking at — status, boards, a board, or a
session — because the question it answers belongs to none of those screens in
particular:

```
⑂  Separate worktree · branch feat/worktrees · the main one is keel-ui   [Unify]
```

It goes in `_ConversationArea` and not inside each view, so it is impossible for
one of the four to forget to show it. **A project in the main worktree — the normal
case — pays not one pixel**: the strip measures zero.

## Unifying

The button opens a panel. Like anything else that decides something in this app, it
is a side panel and not a dialog: paths, branches, and a list of what will be
deleted have to be read, and that does not fit in a yes/no.

The panel enumerates **before** touching anything:

1. Bring `main` (or `master`) from `origin` into the main worktree.
2. Remove the folder next door. Git deregisters it and **deletes it from disk**.
3. Put the branch on the main one, which only now can take it.
4. The project starts running there, with the same branch and the same thread.

### The order is not accidental

First what can be undone, then what cannot. Bringing the base destroys nothing;
removing the worktree does, and by then the rest of the path is known to be clear.

Step 3 cannot go before step 2: git refuses to check out a branch another worktree
has checked out, and until step 2 it did.

### Ignored files are enumerated

`git worktree remove` deletes the whole folder, and with it goes what is IGNORED,
which appears in no `git status`: the `.env` you wrote by hand, the build. Git will
not miss it; you will. That is why the panel lists it beforehand, with names and
counts. It does not block — it is the folder that is going away — but it is stated.

### What does block

They are data, not exceptions: an operation that deletes a folder does not find out
halfway through.

| Blocks | Why |
|---|---|
| A session running in the project | The CLI is writing inside the folder we would be deleting |
| The main repo is `bare` | It has no working copy to move the branch to: this worktree is all there is |
| Detached HEAD, no branch | There is nothing to move to the main one |
| The worktree has `git worktree lock` | Whoever locked it had a reason |
| Uncommitted changes here | They are lost with the folder |
| Uncommitted changes in the main one | Its branch has to be switched, and with those on top it cannot be |

### The pull fails and it carries on

It is the only deviation from "all or nothing", and it is deliberate: bringing
`main` depends on there being a network and on the remote answering, and **neither
of those has anything to do with consolidating two local folders**. With no
network, blocking the whole unification would punish what can be done for what
cannot. It shows in the report, flagged, and the rest continues.

If the main one is already standing on the base, it is a real `pull --ff-only`. If
it is on another branch, the reference is advanced with
`fetch origin <base>:<base>` — the same thing, without the extra checkout.

### Nothing is merged

If the branch fell behind the base, the panel says so with the exact number and
does nothing about it. Merging or rebasing is a decision, and here a branch is
only moved between folders.

### If something fails halfway

The project changes directory **as soon as the old folder stops existing**, whether
the rest goes well or not. Leaving it pointing at what was deleted is the only way
for this to end worse than it started.

And if the final `switch` fails, the report says the only thing that matters: the
commits are there, the branch still exists, and it is taken by hand.

## What the agent receives

When the project runs in a side worktree, the turn adds a section to the system
prompt, right after DELIVERY:

> **WORKTREE**: this directory is a SEPARATE worktree of the repo, not the main
> one. It is already standing on branch `feat/x`, which is this work's branch:
> commit here and do NOT create another branch or switch branches. Where the
> DELIVERY section says "create a branch for the session", that branch is already
> created and it is this one. The repo's main worktree is at `…` and is NOT yours
> this turn: do not check it out, do not switch its branch, do not write inside it.
> Here `.git` is a file and not a folder. That is normal in a worktree and there is
> nothing to fix.

It is not something it could infer on its own: `git status` tells it which branch
it is on, not that the branch belongs to this worktree nor that there is another
copy of the repo next door.

## Where it lives

| What | Where |
|---|---|
| Model and reading | `integrations/git_worktree/src/worktree_place.dart`, `worktree_probe.dart` |
| The plan and its blockers | `integrations/git_worktree/src/worktree_plan.dart` |
| The four steps | `integrations/git_worktree/src/worktree_unify.dart` |
| Per-path cache and the operation | `integrations/git_worktree/src/worktree_viewmodel.dart` |
| The strip and the panel | `integrations/git_worktree/src/ui/` |
| The declaration in the turn | `modules/projects/viewmodel/projects_viewmodel.dart` (`_worktreePrompt`) |

## How it is tested

Parsing `worktree list --porcelain` and the plan's blockers are pure and are tested
on their own.

The rest runs **real git** over toy repos in a temporary folder — including a local
bare `origin`, with no network — because what can go wrong there is not the parsing
but the ORDER of the commands, and a folder deleted at the wrong moment is not
discovered with a mock.
