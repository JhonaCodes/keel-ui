# F20 — Single-file backup

## Problem it solves

The system backup (F21) is ALL-or-nothing, always goes to the vault folder, and
never carries secret values, because that repo gets pushed. The other half was
missing: "I want to take THIS to another machine in one file" — pick what,
see what it overwrites before applying, have knowledge travel with its content,
and be able to move credentials between machines you own.

## What it is

`Settings → Single-file backup`, two side panels:

- **Export**: checkboxes per section (skills, rules, tools, workflows, MCPs,
  knowledge bases, agents, projects) and a separate opt-in for secrets. Pick a
  destination with the system dialog and out comes ONE `.json`.
- **Import**: pick the file, the app INSPECTS it and shows what it brings and
  what it overwrites ("Skills: 12 in the file, 3 overwrite existing ones: …")
  with checkboxes for the sections present in the file. Only then "Apply
  selection".

## The shape is the git catalog's — on purpose

`catalog_shape` exposes its serialization as `catalogAsJson()` and its
merge-by-name as `mergeCatalogJson()`; the backup reuses both verbatim. Two
destinations (the vault zip / a single JSON), ONE shape — two copies of "how a
profile is serialized" drifting apart silently is exactly what must not happen.
Same rules as always: references BY NAME, create-or-update merge, working paths
and sessions never travel, and neither does Keel AI's map (it is recompiled on
every launch).

## What the vault never carries and this file does

- **Knowledge documents**: with the "Knowledge bases" section, the files of each
  LOCAL base that has a folder travel (relative path → content; hidden files and
  anything over 256KB are left out; a git base does not travel — its content is
  recovered by cloning). On import they are written ONLY into bases that already
  have a folder on this machine — paths do not travel and are not invented: a
  base without a folder is recorded in the result ("assign one and import
  again"). After writing, the base is reindexed.
- **Secrets with their VALUES, only by explicit decision** — and this is the only
  path that carries them, because the vault never uploads them. The checkbox says
  it without euphemism: the file carries the VALUES in plain text; it is for
  moving credentials between machines you own, never for sharing. On import:
  missing ones are created, and the value is filled in ONLY for those that are
  pending here. A local secret that has a value is never overwritten from a file.

## Verification

1. Export everything → delete a skill → import only Skills → the skill comes
   back identical and nothing else changed.
2. Selective import: untick a section present in the file → that section is not
   touched.
3. Without the secrets opt-in, the exported JSON contains no `secrets` key; with
   it, the result warns about it.
4. The preview names the items that would overwrite existing ones before
   applying.
