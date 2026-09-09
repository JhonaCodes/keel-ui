# F21 — The system vault

## Problem it solves

The whole system lived in an LMDB inside `Application Support`: skills, rules,
tools, workflows, MCPs, agents, projects, bases, and settings. Uninstalling the
app took the lot. The two pieces that existed were not enough: `catalog_sync`
(F9) pushed the catalog to a repo cloned **inside the very folder uninstalling
deletes**, and the single-file backup (F20) asks for a destination with a dialog
every time, so there is no stable place to version.

The vault is that stable place: a folder of yours, that you version with git.

## What it is

`Settings → System backup`. You pick a folder — the suggestion is
`~/keel-knowledge-bases`, where the local knowledge bases already live, so one
repo carries system and knowledge — and a remote URL. Three buttons:

- **Push to GitHub** writes `keel-backup.zip` into the vault, runs `git init` if
  needed, commits, and pushes. It is a single step on purpose: there used to be a
  separate button that only wrote the zip, and a backup that stays on this disk
  does not protect against losing this disk. Having it next to the one that does
  upload made the cheap half look finished.
- **Restore…** reads the zip, shows what it brings and what it would overwrite,
  and applies what you tick.
- **Clone vault…** is the new-machine path: URL + an empty folder → clone → adopt
  the vault → preview → restore.

Keel AI handles it with `backup_system` (no arguments: writes and pushes) and
`restore_system`.

## What happens without you pressing anything

**On first launch**, if the system is genuinely empty — zero skills, zero agents,
zero projects, not counting Keel AI's map, which is always reseeded — the app does
not show the system: it shows a screen asking for the vault's URL and the
destination folder, clones, restores EVERYTHING, and goes in. One field and one
button. With a populated system it never appears, and restoring goes back to being
the button with a preview: restoring overwrites by name, and that is only done
without asking when there is nothing to lose.

If the folder you choose already has the `keel-backup.zip` because you cloned the
repo by hand before opening the app, nothing is cloned: it is adopted as is.

**While you work, nothing happens.** Nothing backs itself up: there is no timer
and no backup on app close. The only moment a backup is written is when you press
the button or when Keel AI calls `backup_system`.

There used to be an automatic one — every 15 minutes and on app close, with a local
commit — and it was removed. The reason is below, in "The zip is deterministic": a
zip does not diff, so **every commit puts the whole file in again**. With a 50 MB
backup every fifteen minutes, the vault's `.git` reached **25 GB** without anything
saying so. The size containment exists (a single commit, see below), but the volume
the automatic one generated outran it anyway: the real cure is not backing up when
nobody asked.

Commits created by Keel pass `--no-gpg-sign`. The app can be launched from Finder
with a `PATH` that has no `gpg`, and it has no safe interactive terminal to ask for
the pinentry. The override affects only that command: it does not modify
`commit.gpgSign` nor the signing of commits the user makes.

## Being saved and being safe are not the same

Unstated, "saved" and "saved somewhere that survives this machine" look identical.
That is why the rail has a **Backup** entry with a red dot, and the panel a written
notice, both answering the first rung that fails:

1. You have not picked a vault folder.
2. **The last operation failed.**
3. There is no backup yet.
4. The vault is not a git repo.
5. The repo has no remote.
6. The committed backup is not pushed.
7. **The last backup is more than 3 days old.**

It is a ladder and only one rung is answered: telling somebody "you did not push
it" when they have not even configured a remote helps them with nothing.

Rung 2 was added after it happened: a backup that blows up is **invisible** without
it. The old zip is still on disk with its date, so `lastBackupAt` says a backup
exists, the repo is up to date, and the lower rungs pass straight through. The
notice carries the FIRST line of the error — an isolate error is two hundred lines
of `<- _child in Instance of ...` — and the whole text stays in the panel.

Rung 7 is the net that replaces the automatic one. Without it, going manual meant
that an impeccable vault with last week's zip looked exactly like an up-to-date
one, and the rail's dot stayed green forever: `lastBackupAt` comes from the `mtime`
and was never compared against today.

## The zip is deterministic, and git surviving depends on that

A zip does not diff: every version is a whole new blob. The containment is for the
zip to be a **pure function of the state**: entries sorted alphabetically, a fixed
date (`1980-01-01`) on all of them, and **no timestamp inside**. Backing up twice
without having changed anything yields identical bytes, `git commit` answers
"nothing to commit", and the repo does not grow.

When the state DID change, the containment is different and it is two pieces
working together (`vault_git.dart`):

- **A single commit, always.** Each backup REPLACES the previous one: if the tip is
  already the root commit it is amended, and if history accumulated, the branch is
  deleted so the next commit is born with no parent. There is no version history of
  the vault, on purpose: each one would weigh the whole zip.
- **The pruning, which is what actually shrinks it.** Rewriting the commit leaves
  the previous blob *unreachable*, not deleted: `git log` shows one and the `.git`
  grows anyway. That is why after rewriting it runs
  `reflog expire --expire=now --all` and, if needed, `gc --prune=now`.

The "if needed" is a ceiling **proportional to the backup** — twice the zip's size,
with a 1 MiB floor — not a fixed number of MB. An absolute threshold cannot serve
both a 5 MB vault (it would never prune) and a 500 MB one (it would prune on every
click, and the vault carries the knowledge bases in the clear, so that is thousands
of files). It is watched by the *"backing up many times does NOT inflate the .git"*
test in `test/system_vault/vault_git_test.dart`, which backs up ten times with
different incompressible bytes and fails if the `.git` exceeds four times the file.
Without the pruning, that same test gives ten times.

That is why the backup's date comes from the file's `mtime` and from the commit's
message, never from the manifest. A `DateTime.now()` in there would break the whole
property: `test/system_vault/vault_archive_test.dart` watches it.

## What travels

```
keel-backup.zip
├── manifest.json      version + how many of each thing
├── settings.json      text size, permissions, repos
├── secrets.json       [{name, description}] — NO values
├── catalog/<category>/<name>.json
└── knowledge/<base>/<path>   local bases from OUTSIDE the vault only
```

What does NOT travel, on purpose: chat threads (`agent_`, `session_`, `msg_`),
attachments, prompt logs, the jobs API token, the projects' working paths, the
window size, the vault's folder, the re-clonable git mirrors, and Keel AI's
compiled map.

**Nor the secrets' values.** The vault gets pushed to a remote, and what enters
git's history never leaves: only the names and the description travel, and on
restore the secrets are left **pending**, with the list of which to fill in. To
move the values between machines you own there is the single-file backup (F20),
with its explicit opt-in.

**Internal requirements** (F26) do travel, and they are the exception that proves
the rule above: they are not one session's noise, they are a decision between two
projects. They travel by code, with the projects by name. On restore they are
**created if missing and not overwritten if present**: a requirement is a live
conversation, and restoring the backup's snapshot on top would erase everything
said since.

The `stations` category of old backups is still **read** as `projects` (F24).
Writing always writes the new name: that way the old format switches itself off
instead of staying forever.

A document larger than 10 MB does not enter the zip — a huge binary in a repo stays
there forever. What is skipped is **named** in the result: a silent cap would read
as "I saved everything".

## The knowledge bases that live in the vault

The standing rule: absolute paths do not travel. The bounded exception is the path
**relative to the vault**. A local base hanging off the vault travels as
`vaultPath: "ux-ui-catalog"` and **its documents are not copied into the zip** —
they are already in the repo, in the clear and diffable — and on restore it
reattaches itself against that machine's vault. A local base from outside still
travels with its documents inside the zip and arrives with no folder, as before. A
git base does not travel: it is recovered by cloning.

That is what makes `clone → restore` on a new machine ask nothing about knowledge.

## One shape, several destinations

`catalog_shape` is now the library that defines **how** the catalog is serialized
(`catalogAsJson`), how it is merged back (`mergeCatalogJson`), what sections exist
(`BackupSection`), what a backup would overwrite (`backupPreviewOf`), and the save
that waits for the catalogs to be genuinely loaded (`awaitCatalogsReady`). It lived
inside `catalog_sync`; it came out of there when that integration was deleted. The
vault and the single-file backup both consume it: two copies of "how a profile is
serialized" drifting apart silently is exactly what this separation avoids.

`catalog_sync` (F9) is removed — the vault replaces it and does more.

## Verification

1. `flutter test` — a round trip with accents and binaries, byte-for-byte
   determinism, named errors for somebody else's / corrupt / not-a-zip file, the
   `..` guardrail on paths, and the notice's ladder.
2. Pick the vault → **Back up** → `unzip -l` shows the categories, and a base that
   lives in the vault does **not** appear under `knowledge/`.
3. `unzip -p keel-backup.zip secrets.json` contains no value.
4. **Back up** twice in a row without touching anything → `git status` clean.
5. Delete a skill → **Restore…** → the preview names it → apply → it comes back.
6. Move the LMDB aside and launch: the welcome must appear. Paste the URL, fetch
   everything, and the system returns with the secrets pending.
7. With the vault committed and unpushed, the rail shows the red dot and Settings
   says how many backups are unpushed. After **Back up and push**, both disappear.
8. Close the app with an unbacked change → reopen → the zip includes it.

Note: the commit uses the Git identity the user configured, but Keel disables GPG
signing only for its own backups.
