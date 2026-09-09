# F42 — Arranging the sidebar: groups and order

## Problem it solves

The sidebar's three lists — projects, requirements, and loose agents — showed
whatever existed in the order it had been created, and nothing more. With ten
projects and twenty agents, finding one means reading the whole list; and the
things that belong together in the user's head — a client's three repos, an
experiment's agents — ended up scattered among the rest.

Now they can be **grouped by dragging** and **ordered by hand**, in all three
sections, with the same gesture.

## One gesture, two meanings

Dragging has to be able to do two different things without having to choose
which one beforehand. What separates them is **where** you drop inside the row:

| Where you drop | What happens | What you see before dropping |
|---|---|---|
| Top quarter | goes before | a line above |
| Bottom quarter | goes after | a line below |
| Middle half, over an item | a group is born with both | the row lights up |
| Middle half, over a group | joins that group | the row lights up |
| Over the section title | leaves the group, back to the root | the title lights up |

A group is renamed with a **double click** — the same `InlineRenameField` that
already renamed a project or a session — folded with the chevron, and undone
with a **right click**.

## The rules that hold it all up

**A single level.** A group does not go inside another. With nesting, moving
something stops having a single meaning and the list becomes a tree to navigate
instead of a list to read. Dragging a group onto another orders it behind; it
does not put it inside.

**A group with fewer than two members dissolves itself**, and the survivor
returns to the root in the place where the group was. A group is born from
joining two things; with only one inside it groups nothing, and it would be the
leftover of a move rather than a decision.

**Sections do not mix.** What is dragged carries which section it came out of,
so dropping a project onto an agent does nothing.

## What is stored, and why like this

One record per section (`sidebar_layout_project`, `…_requirement`, `…_agent`),
with the list of slots in order: each slot is either a loose item or a group with
its ordered members.

It is not a `groupId` on `Project`, `InternalRequirement`, and `Agent`: that
would be three models, three repositories, and three `toJson`s to express
something that belongs to **the view**. On top of that, the requirements
repository reorders by date on load and the agents one guarantees no order at
all, so a per-item field would have to fight both.

**The layout is a hint; the catalog is the truth.** On draw it reconciles: an
item that exists and is not listed shows up anyway, at the end of its section;
one that is listed and no longer exists is discarded. Without that rule, an old
layout could hide a real project — the only way this could do harm.

A group's folded state **is** persisted, unlike Boards or Sessions: those belong
to the open project, there is only one at a time, and a group that unfolds itself
on every launch is no help in arranging anything.

## What is NOT touched

The sections inside a project — Status, Boards, Sessions — are not items in a
list: they are the parts of the open project. They hang off the project's row but
stay outside the drag zone, because dropping something onto "Sessions" means
nothing.

## Verification

1. Drag a project onto another: the group appears with both inside.
2. Double click the group's name: it renames in place; empty is rejected without
   closing the edit.
3. The chevron folds and unfolds it; closing and reopening the app preserves it.
4. Dragging to the edge of a row reorders instead of grouping.
5. Dragging a member onto the section title takes it out of the group; if it was
   the second to last, the group disappears.
6. The same, identically, in requirements and in loose agents.
7. Deleting a grouped project does not hide the others.
