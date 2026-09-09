# F38 — Explicit references in a session's chat

## Problem it solves

Writing "look at the folder", "use the skill", or "check the knowledge" forces
the agent to guess names and locations. It was also impossible to address a
message to a specific project member from the composer itself.

Session chat recognizes four prefixes anywhere in the message and filters the
catalog as you type:

| Prefix | Catalog | Example |
|---|---|---|
| `/` | Directories inside the project | `/lib/src` |
| `@` | Agents that are members of that session/project | `@nova-builder` |
| `$` | Registered skills and rules | `$tdd-workflow` |
| `#` | Knowledge bases and documents | `#architecture/decisions.md` |

Arrow up/down changes the option, Enter or Tab inserts it, and Escape closes the
list. Mouse selection works too. A compact legend below the composer keeps the
commands visible.

## What gets persisted

References to directories, skills, rules, and knowledge are stored as readable
Markdown links whose target is a typed `keel://` URI. The user sees the chosen
name and the runtime keeps the exact ID or path. That way two resources with
similar names cannot be confused, and a queued message keeps the same reference
until it is sent.

An `@agent` mention is readable text, because the agent is already restricted to
the project's resolved members. In a follow-up, that mention picks who receives
the next turn. On the first message it does not bypass the preflight or the
workflow: it merely takes part in the normal resolution of owners.

## How it reaches the turn

Before opening the provider's process, Keel resolves only the message's explicit
links:

- a directory contributes its absolute path inside the working directory;
- a skill or rule contributes its currently registered content;
- a knowledge base contributes its brief;
- a text document from knowledge contributes its content, and a binary one
  contributes its path so a compatible tool can read it.

That context is attached to that turn; it does not permanently modify the
project or the workflow. Deleted, invalid, or tampered links are ignored.

## Security and cost limits

- Directories are discovered only beneath the project, without following
  symlinks, and skipping heavy folders like `.git`, `build`, and `node_modules`.
- A path trying to escape with `..` never enters the prompt.
- Each resource and the total sum have size limits, so a single mention cannot
  consume the whole context.
- Only effective members appear under `@`; typing the name of an agent from
  another project neither adds nor runs it.
- Mentions inside inline code or code blocks do not change the turn's owner.

## Verification

1. Typing each prefix opens its catalog and filters by name or description.
2. Choosing an option replaces only the active token and leaves the cursor after
   it.
3. References work in the middle of a message and survive in the queue.
4. The prompt contains the chosen resources, but no paths outside the project.
5. `@member` directs a follow-up; a mention in code or to a non-member does not
   change the owner.
