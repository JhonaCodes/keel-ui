# F27 — Startup, and saying that you are waiting

## Problem it solves

Opening keel-ui and not being able to click for twenty seconds. The window was
already there, with content, and did not respond.

The obvious reading — "it is loading, an indicator is missing" — was the wrong one,
and it is worth saying why: **there already was an indicator**. `VaultBootGate`
showed a `CircularProgressIndicator` during exactly that interval. What happened
is that it did not spin. The UI thread was not busy: it was **blocked**, and a
spinner needs frames to spin.

Hence this work's order: first unblock the thread, then add the bar. A bar over a
blocked thread freezes just the same.

## What was blocking

### The database was read whole, over and over

`flutter_local_db` has no prefix query. It only knows how to return **one** key
(`GetById`) or the **whole** database (`GetAll`). So
`LocalDatabase.getAllWithPrefix` fetched everything and filtered in Dart.

And `GetAll` is not a read: it serializes the entire database to JSON, crosses it
over FFI, decodes it, and then **re-serializes and re-parses record by record** —
plus another `jsonEncode` per record to compute its hash. That is three to five
serialization passes over the whole database **per call**. The signature is
`async` but the body has not a single `await`: it never yields the thread.

With the database at 5.5 MB, startup did **eleven plus one per session**: two from
Keel AI's seed, seven from the catalogs, one from projects, one from agents, and
**one for each session** to gather its messages. Each one deserialized every
message of every session in order to discard 99%.

It was not only startup. `ProjectsRepository.save()` did
`1 + projects + sessions` of those reads and is called from forty places in the
ViewModel; `PromptInsights.record()` did another on every message you sent. That
was the stutter you felt while working.

### The knowledge index was built before the first frame

`KnowledgeViewModel` did not resolve its `ready` until indexing finished, and
indexing walks each base's disk with a recursive `listSync` plus a
`readAsStringSync` per cover page. With twelve bases registered that was about
6,700 entries — one folder alone had 4,608.

And the 5,000-file cap did not cut the directory recursion: the budget cutoff was
only on the files branch, so a large tree was walked entirely even when there was
nothing left to index.

Since `KnowledgeService.ready` was part of `awaitCatalogsReady()`, that entire
walk happened before the app let anything be seen.

## What was done

### The database is read once and stays in memory

An index by key inside `LocalDatabase`, which already was — and its own comment
said so — the project's only file that imports `flutter_local_db`. Prefix queries
filter that map: zero FFI, zero JSON.

Three decisions keep it from desynchronizing:

- Writes update the index **after** the database confirmed. A write that fails
  cannot leave the index claiming it succeeded.
- Writes that land **while the index is loading** are stored separately and
  applied on top when it arrives. The window is narrow but it exists.
- Everything goes in and out **copied**. Each read used to return objects freshly
  parsed from JSON, so nobody could clobber another's stored record; returning the
  index's reference would have changed that rule silently, and a
  `record['x'] = y` in any repository would corrupt the in-memory database without
  a single error.

The copy going stale is not a real risk here: sub-windows do not even write — they
declare `markUnavailable()` for that — and nothing outside the app touches that
file. There is nobody to make it diverge.

What it costs is memory: the whole database stays resident. If that ever becomes a
problem, the way out is pruning old messages, not scanning again.

### Knowledge indexes in the background

`ready` and `indexReady` become two things, because they are two things:

| | Resolves when | Who waits for it |
|---|---|---|
| `ready` | The base catalog has loaded | Startup, and the UI to draw the list |
| `indexReady` | The index has finished building | Assembling an agent's turn |

The only thing that needs the MAP is the turn: without it, the agent does not see
what is inside its bases. There, waiting on disk makes sense. To draw a list of
names, it does not.

## The bar, and what it means

A 2px strip pinned to the top and the screen dimmed, mounted in the `MaterialApp`'s
`builder` — the only place that covers the whole app, side panels included, since
those are routes of the same Navigator.

- **Dimming rather than covering**: you can see the app is there and nearly ready.
  That is different from a loading screen, and it is information.
- **Taking no layout**: it appears and disappears without moving a pixel of what is
  underneath. It is the same `SizedBox(height: 2)` the chat and the channel already
  use.
- **`AbsorbPointer`**, and it is not decorative: the clicks you made during startup
  were queued and all fired at once when it unblocked, opening panels nobody asked
  for.

The state is a **counter**, not a boolean: two long tasks can overlap and whichever
finishes first must not switch off the other's notice. `during(label, work)` is
the single entry point, with a `finally`, so a task that blows up does not leave
the app dimmed forever.

It is switched on by startup, backing up, restoring, fetching the vault, importing
a catalog, and updating a knowledge base.

## `VaultBootGate` stopped blocking

It waited for the eleven catalogs to decide whether to show the welcome, and
meanwhile replaced the whole screen with the spinner. But the flag it needs —
`vaultOnboardingDone` — comes from the settings, which is **one key**. With the
flag set, which is the usual case, it answers instantly.

Only if the welcome was never done does it need to know whether anything is stored,
and for that the catalogs do have to be awaited: asking earlier would answer
"empty" always, and the welcome would appear to somebody who has everything.

## Verification

1. Open the app: the UI is dimmed, with the bar **actually animating**, and it
   switches off on its own.
2. Pressing the rail while dimmed opens nothing when it unblocks.
3. `put` and then reading with `getAllWithPrefix` returns the new value; `delete`
   removes it; `replaceAllWithPrefix` leaves exactly what it was given.
4. What is read cannot corrupt the index: mutating the returned map does not change
   what is stored.
5. A turn that uses a knowledge base receives the complete map, even when fired
   right after the app opens.
6. Send a message in a session with a long history: no stutter on save.
7. Restoring a backup switches on the same bar and switches it off when done, even
   on failure.
