# F16 — Knowledge bases

Replaces **F11 (Knowledge section)**: a single global folder, flat-indexed and
tied to nothing. Its delivery point to agents
(`KnowledgeViewModel.mirrorPathIfPresentSync`) was assigned and read by nobody,
so no agent knew the knowledge existed.

## What it is

Knowledge stops being a folder and becomes a catalog of **bases**, each with its
own name and context boundary: `ATLAS`, `HORIZON`, `NORTHSTAR`. A project sees its own
and no others.

## The model

`KnowledgeBase`: a unique name, a one-line description (*what this base answers*)
and a source.

| Source | Where it lives | Syncing |
|---|---|---|
| `git` (url + branch) | `AppSupport/knowledge/<name>/` | clone / `pull --ff-only` |
| `local` (a path on disk) | the folder itself, uncopied | nothing to sync |

A complete catalog module (model + repository with the `knowledgebase_` prefix +
ViewModel), like skills or rules: which is why it enters the export and
`list_catalog` on its own.

## The boundary

- `Station.knowledgeBaseNames` — by name, like `ruleNames`.
- `AgentProfile.knowledgeBaseNames` — the **oracle** case: an agent whose job is
  to answer from a base, usable 1:1 outside any project. It is a deliberate
  exception to the isolation — that base travels with it.

`Station.documentPaths` **disappears**: a loose document is a local base pointing
at its folder. Two mechanisms for "you consult here" was the redundancy that cost
two lists on every turn.

## What an agent receives: the map, not the territory

Per linked base, the turn receives a fixed-size summary — it does not matter
whether the base holds 60 documents or 6,000:

```
Knowledge base "ATLAS" — API contracts, domain, and processes of the Atlas platform.
Root: /Users/…/knowledge/ATLAS  (63 documents)
  api/ (14) · domain/ (9) · processes/ (7) · release/ (3)
Search here with Grep/Read when you need a project fact.
```

If the root has an `INDEX.md`, **its content is injected** (with a size cap). That
file is written by the user and is the cover: it is what turns "knows where to
look" into "knows what to look for".

No MCP tool is needed to read: reading and searching files is always permitted
(`kAlwaysAllowedTools`), so it works the same with `claude` and with `codex`. The
same summary is built by a single function, consumed by `_turnSystemPrompt`
(projects) and by `_resolveProfileSystemPrompt` (1:1).

## The screen

A tree on the left: bases at the root, expandable folders, files as leaves, read
live from disk. A viewer on the right, by extension, with packages already in the
pubspec:

| What | With what |
|---|---|
| `.md` | the chat's renderer **with its `codeBuilder`**: ```mermaid``` and ```svg``` blocks are drawn as diagrams |
| `.svg` | `flutter_svg` |
| images | `Image.file` |
| code and text | `flutter_highlight` |
| everything else | a card with "open with the system app" |

Lucidchart is a web service, not a file: there is nothing to render inside the
app. What works is exporting the diagram to `.svg`/`.png` inside the base, or
leaving a `.md` with the link. Mermaid is native and lives versioned as text.

## Syncing

A button per base and "update all" on the screen. `sync_knowledge(base)` as a
Keel AI tool, to ask for it in conversation. Nothing runs in the background.

## What Keel AI can do

| Tool | What for |
|---|---|
| `create_knowledge_base` | Registers the base. With `source: "local"` it **creates the folder if it does not exist** — that is the path for an agent to build a base and write inside it. From the form, validation stays strict: there, a nonexistent path is a typo. |
| `update_knowledge_base` | Name, description, or source. Only what it sends. |
| `delete_knowledge_base` | Removes the record. **It does not delete the documents on disk.** |
| `sync_knowledge(base?)` | Pull plus reindex; without `base`, all of them. |
| `list_catalog(kind: "knowledge_bases")` | Name, document count, and description. |
| `get_item(kind: "knowledge_base")` | Root on disk, size, problems, and which projects use it. |
| `update_station(knowledge_base_names)` | Gives it to a project. The list replaces the current one. |
| `create_or_update_agent(knowledge_base_names)` | The oracle case. |

The content is written by the agent with its own file tools inside a local base's
root: there is no tool for writing documents, because `Write` already exists and a
parallel tool would only add one more way to do the same thing. In a `git` base
the mirror is not written to — whatever gets written there is lost on the next
pull; changes go to the repo.

## What travels in the export

Two levels, and the second is chosen per base:

1. **The definition** — name, description, git source (url + branch), and which
   projects and profiles use it, by name. Small, always included.
2. **The content** — the documents themselves, embedded in the backup file.
   Optional per base, because not all of them need it:
   - a `git` base is recovered by cloning, so its content is redundant;
   - a `local` base **exists only on this disk**: without its content, the backup
     backs up nothing.

Paths never travel (the same convention as a project's `workingDirectory`). On
import:

- if the content came in the file and the base has no folder with documents, it is
  restored into `AppSupport/knowledge/<name>/` and the base points there;
- if the base already has documents on disk, the embedded content is **not
  written**: importing never overwrites what is already there.

The export panel shows the bases one by one with their estimated size, so
including the content is an informed decision and not an 800 MB surprise.

## Migration from F11

`settings.knowledgeRepoUrl` is read **exactly once**: if no base is registered and
that URL is not empty, the `knowledge` base is created with it and the field is
left blank. The "Knowledge" section leaves Settings in the same move.
