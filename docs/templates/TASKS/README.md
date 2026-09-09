# <The project's end goal>

One or two sentences: what is true once ALL of this is done. Not the list of
tasks — the state of the world at the end.

## Folders

The number decides the order in which they are to be taken.

| Folder | What it covers | State |
|---|---|---|
| `01-descriptive-name` | … | in progress |
| `02-next` | … | pending |

## How work happens here

1. `list_roadmap_tasks` to see what exists and what is claimed.
2. `claim_task` on the one you are about to do. If it fails, somebody got there
   first: move to the next one, do not insist.
3. When done: `estado: hecho` in the task's file, and `release_task`.

If you touched this folder's structure, run `check_roadmap_format` before closing.
There is no `keel` command that does this: it is that tool.

There is no tracking file and no claims file. State lives at the top of each task
— so two agents finishing different things do not collide — and who has it claimed
lives in keel-ui, which is the only thing that needs to be atomic.

> **The frontmatter keys stay in Spanish** (`estado:`, `prioridad:`, `titulo:`,
> and the `## Bloqueantes` heading). They are not prose: the reader matches them
> literally (`roadmap_reader.dart`), so translating them would break every existing
> `TASKS/` folder. The prose around them is English.
