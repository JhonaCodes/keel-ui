# F39 — Locks: what a tool cannot touch on its own

## Problem it solves

Keel AI and agents with catalog access can create, update, and delete skills,
rules, tools, agents, workflows, projects, hooks, MCPs, boards, secrets, and
knowledge bases. That is the point of the app. But some things work and are not
to be touched: the rule that makes the team write tests first, the agent that is
already tuned, the production project.

A lock does not stop you: **it stops the tools**. An agent that wants to change
or delete a locked item has to ask you first, saying what it will change and why
(`change_intent` / `change_reason`), and you see that request in the thread
before anything happens.

## How a lock is identified

By the pair `(type, name)`, not by id: `skill:tdd-workflow`,
`rule:sin-fuerza-bruta`, `mcp_server:github`. That is what is visible in the UI
and what an agent writes in a tool call, and it survives the item being saved
again.

Boards are the exception, because they are only unique within a project: their
lock name is `project · board`.

Renaming an item **moves** its lock: otherwise renaming would be the trivial way
to shed it.

## A lock that sets itself

`lock_registry:registry` always exists and is re-created if missing. It is what
makes **setting or removing a lock through a tool** also require permission —
without it, the first move of an agent that wants to change something protected
would be to unlock it.

That is why it appears separately on the screen, under "System", with no button.

## Where they are all seen together

A lock is set from each item, with the button on its row. Removing one was also
one at a time, which with twelve catalogs meant that remembering what you had
protected required walking through all of them.

**Settings → Locked items** shows the complete list, grouped by type, with
unlocking in place. It is exactly what an agent sees when it calls
`list_locked_items`: the same data, not a copy.

## Verification

1. Lock a rule from its tile: the button turns closed and edit and delete become
   disabled.
2. Open Settings → Locked items: the rule appears under RULE.
3. Unlock from the panel: it disappears from the list and its tile allows editing
   again.
4. With nothing locked, the panel explains what a lock is for instead of showing
   an empty list.
5. The system registry is always visible and has no button to remove it.
