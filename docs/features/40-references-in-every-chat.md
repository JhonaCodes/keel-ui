# F40 — The same references, in every chat

## Problem it solves

[F38](38-chat-references.md) gave a session's chat four prefixes for naming
things without the agent guessing: `/` folders, `@` agents, `$` skills and
rules, `#` knowledge bases.

And it stopped there. Keel AI's chat, a 1:1 agent's chat, and a requirement's
thread were still a bare text field. Keel AI in particular — which exists to
build the app's configuration — could not name the skill it was about to touch.

The four prefixes now belong to the app, not to one module.

## The only thing that changes between places

Which universe can be named. That is the *scope*:

| Scope | `/` folders | `@` agents |
|---|---|---|
| Project session | those in the project's working directory | the channel's members |
| Everywhere else | the registered projects and the known roots ([F41](41-roots-and-volumes.md)) | the whole profile catalog |

Skills, rules, and knowledge are global catalogs: they read the same from both
sides.

Inside a session, `@handle` additionally **directs the turn** to that member.
Outside there is no channel and no turns to hand out: there, `@` serves to talk
*about* an agent, and the link is readable text.

## Why a folder's link now says what it hangs from

With a single project the relative path was enough:
`keel://directory?path=lib`. With no project there are ten possible roots and
`lib/src` exists in all of them, so the link carries its root too. Old links —
those in a message left in the queue — still resolve: with no declared root, the
only one the scope has is used.

A declared root only counts if it is still a root of the scope. A hand-forged
link pointing at `/etc` resolves to nothing.

## Keel AI's window has no database

It is a separate engine, and deliberately does not open the database
(`markUnavailable`): its catalogs are empty. It cannot build the suggestion list.

So it does not build it: it asks the main engine through the same bridge it
already uses to send a message (`assistant.referenceSuggestions`). That is the
only call on that port that awaits a response — everything else is fire and wait
for the next snapshot. If the trip fails, the list stays empty and the composer
remains an ordinary text field: it never breaks typing.

**Resolution** does not travel: the turn runs in the main engine, which is where
`keel://` becomes content.

## What gets stored in a requirement

Readable text, not links. A requirement crosses projects and travels in the
backup, where this machine's paths are stripped on purpose: naming the folder is
useful, storing its absolute path is not.

## Verification

1. In Keel AI's chat type `$`, `@`, `/`, and `#`: each one opens its catalog and
   filters as you type.
2. Pick a skill and send: the turn receives its content, and the thread still
   reads the name.
3. The same in the 1:1 chat and in a requirement's thread.
4. In a project session nothing changed: `/` still shows only that project's
   folders and `@` only its members.
5. A queued message written before this change still sends correctly.
