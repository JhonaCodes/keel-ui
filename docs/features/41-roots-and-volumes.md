# F41 — Other disks, and where your projects are

## Problem it solves

The app assumed a single place: the boot disk.

- The folder picker opened wherever the system felt like — the user folder — so
  anyone with their projects on another partition navigated the whole tree every
  time they created a project or a knowledge base.
- A 1:1 agent — and Keel AI — runs with its working directory in `$HOME`,
  because it has no project assigned. Asking it to "look at project X" sent it
  hunting where the project is not: it walked the user folder, found nothing,
  and concluded the project does not exist, or invented a path.

With projects on `/Volumes/Data`, `D:\`, or an external disk, both things fail
for the same reason: nobody told anybody where they are.

## Two lists, and neither one guesses

**Mounted volumes** are asked of the operating system, and each one exposes them
somewhere else: macOS under `/Volumes`, Linux under `/media/$USER`,
`/run/media/$USER`, or `/mnt`, Windows as drive letters. All 26 letters are
probed and existence decides — asking is cheaper than any API. It is what exists
*now*, not what is assumed.

**Known roots** are the folders this user has used, ordered by use and stored in
the local database. They feed themselves from two places: every folder chosen in
a picker, and every project's working directory. Nobody administers them by
hand. Up to 30 are kept — it is a list to choose from, not a history.

A path that no longer exists is not recorded: the list exists to offer places you
can go to, and an unmounted disk is not one.

## What they are used for

1. **Every folder picker** opens in the last one you used, instead of the
   system default.
2. **The composer's `/`** with no project
   ([F40](40-references-in-every-chat.md)) offers those roots.
3. **The prompt of an agent with no project** carries a section with the
   registered projects and their absolute paths, and tells it explicitly that
   they may be on another disk. If what it is asked about is in none of them, it
   asks instead of walking the disk.

In a project session that section is unnecessary: there the turn already runs
standing in the right folder.

## A root's key is not its path

A path brings slashes, colons, spaces, and accents, and a database key is no
place for any of that. What gets stored is a readable slug plus an FNV-1a
fingerprint of the full path: two folders with the same name on different disks
do not collide, and the key is the same on the next run — `String.hashCode` does
not guarantee that, and a key that changes when the app reopens is a duplicated
row per launch.

## Verification

1. Create a project choosing a folder on another volume; create another one: the
   picker opens there and not in the user folder.
2. Ask a 1:1 agent about that project: it uses the absolute path without going
   hunting.
3. With `/` in Keel AI's chat, the project on that volume appears.
4. Unmount the disk and reopen the app: the path stops being offered.
