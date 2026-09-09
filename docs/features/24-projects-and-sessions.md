# F24 — A station is a project, and its task is a session

## Problem it solves

Two, and the second one was the one that hurt.

The first is that the name lied from the start. The model's own comment said
*"The context of a PROJECT"*, its working folder was already the identity the
roadmap uses to separate one repo from another, and its rules existed so that
*"one project does not know things about another"*. All the vocabulary around it
said project; only the class said station.

The second is a real collision. **"Task" meant two things at once**: the
channel's thread (`StationTask`) and the roadmap's task in `TASKS/`. While they
were two different screens you could live with it; the project status (F25) puts
both in the same table, and there you cannot.

```
before                         now
Station  ──> Task              Project ──> Session
             (channel thread)              (channel thread)
   TASKS/ ──> task                TASKS/ ──> task
             (roadmap's)                     (roadmap's)
```

## What changed

Everything: symbols, texts, file names, database keys, the backup category, and
the local API's routes. Renaming halfway — the screen in one language and the code
in another — is exactly what was already happening.

One case stands for the rest: `StationTask.sessionsByProfileId` stored the **CLI's**
sessions. With the task now called a session, that line said session twice and
neither one was the same. It is now `cliSessionsByProfileId`, and "session" means
one thing only.

## What was stored on disk

It is the only part that could lose data, so it is the only one with a test.

| Before | After |
|---|---|
| `station_<id>` | `project_<id>` |
| `task_<station>_<task>` | `session_<project>_<session>` |
| `msg_<session>_<n>` | unchanged — it carries the session's id, which did not change |
| the backup's `stations` category | `projects` |
| `POST /stations/<n>/tasks` | `POST /projects/<n>/sessions` |

`migrateStationsToProjects()` **writes, verifies, and only then deletes**.
Writing is idempotent because the ids do not change: a run cut in half duplicates
nothing, and the second writes the same thing over it. And the flag is set at the
end: while it is absent, the old records stay whole and the migration retries
itself on the next launch. That is the way back.

Inside the payload only two field names move (`taskIds` and `activeTaskId`). The
less a migration transforms, the less it can break.

**The formats that face outward still answer.** A backup `.zip` made before the
change imports fine, because `stations` is still READ as an alias of `projects`
(when writing, it always writes the new name). And `/stations/<n>/tasks` still
answers: out there may be a cron written months ago that has no reason to learn
that we changed the words in here.

## Renaming a project in place

Double click on the name and the text becomes a field. The pattern already
existed and worked — sessions used it — but it lived written inside the row; it is
now `InlineRenameField` and both use it.

What it adds: **an invalid name does not close the edit**. The error appears below
and the cursor stays where the fix is needed. Closing the field and reopening it
to fix one extra hyphen is the kind of friction that makes people never rename
anything.

Renaming is safe by construction: nothing points to a project by name except the
local API's route and the roadmap's claims, which expire on their own after 30
minutes.

## Deleting it, by typing the name

The app's other deletions confirm with a button, and that is right: a rule gets
written again. A project does not — it takes its sessions, its threads, and the
context the agents accumulated with it.

The dialog enumerates what goes **before** taking it (N sessions, M messages, the
claims released, the requirements left marked) and answers the question everybody
has in mind: **the repo's folder is not touched**. The button stays disabled until
the text matches exactly.

Typing the name is not an obstacle: it is the second of pause needed to read that
list.

## When the project is not yours

`Project.maintained`. When false, the project is **read-only**, and that is done
the only way that works: **by taking away the tools that write**.

Asking for it in the prompt would be asking. A tool that is not in the turn cannot
be used no matter how much the model wants to, no matter who asks it, and no
matter what it comes up with. The user's own tools do stay: they are theirs, and
marking the project as somebody else's says nothing about them.

Besides, a project like that does not take incoming requirements (F26): they are
recorded as external, for you to resolve.

## Verification

1. Migrate with real data: projects, sessions, and messages appear identical.
2. Kill the app mid-migration and reopen: it finishes, without duplicating.
3. A backup `.zip` made before the change still imports.
4. `POST /stations/<n>/tasks` and `GET /tasks/<id>` still answer.
5. Double click renames; an invalid name shows the error without closing.
6. Deleting demands the exact name, enumerates what it takes, and the repo's
   folder is still there.
7. A project marked as not maintained runs a session and the turn receives no
   Bash, Edit, or Write.
