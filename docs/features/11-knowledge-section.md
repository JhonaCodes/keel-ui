# F11 — Knowledge section

> **Superseded by [F16 — Knowledge bases](16-knowledge-bases.md).** What is
> described here — a single global folder, flat-indexed and tied to no project
> — no longer exists in the code. It stays as a record of where this started.

## What it is

Markdown documentation pulled from a git repo configurable FROM THE UI
(Settings → Knowledge → URL), browsable inside the app (book icon on the rail).

## Mechanics

- `KnowledgeViewModel.update()`: `clone --depth 1` or `git pull --ff-only` into
  `Application Support/knowledge/repo`, then reindexes every `.md` recursively,
  excluding `.git/`.
- Screen: a list filterable by name (with its folder as subtitle) plus a
  `GptMarkdown` viewer — the same renderer the chat uses — with text selection.
- An **Update** button on the screen; Keel AI can also trigger it with
  `update_knowledge`.
- Agents can READ the documents with their file tools — Keel AI's seed tells
  them where those live.

## Initial content

The user's call, since the URL is fully configurable. The natural candidate: a
curated subset of an existing team workspace's documentation — a few hundred
`.md` files in plain markdown, compatible with no conversion.
