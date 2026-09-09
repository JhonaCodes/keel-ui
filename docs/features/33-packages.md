# F33 — Packages: taking a whole agent to another machine

## Problem it solves

An agent that works well is not a prompt. It is a prompt **plus** three skills,
two rules, a tool, a hook that runs it, an MCP server, and a knowledge base.
Sending it to somebody meant sending the prompt and letting them discover, bit by
bit, everything that was missing.

The two backups that already existed do not serve that, and it is not an
oversight:

| | What it carries | For whom |
|---|---|---|
| [F21](21-system-vault.md) `system_vault` | the WHOLE system, versioned in git | you, on another machine |
| [F20](20-single-file-backup.md) `catalog_backup` | whatever you choose, in a JSON | you, by hand |
| **F33** `catalog_bundle` | **ONE thing and its dependencies** | **another person** |

That last column drives every decision here.

## What travels

A **closure**: the root and everything it needs to work the same on the other
side. The function that computes it is pure and touches nothing in the app,
because it is the only thing that decides what leaves your machine.

| You package | It takes |
|---|---|
| **skill** | the skill, and nothing else — it is text |
| **agent** | its profile + skills + rules + tools + hooks + MCPs + knowledge bases, with the documents |
| **workflow** | the workflow + **every** agent that could occupy each role today, each with its own |

Two closures that look excessive and are not:

- **The tool a hook runs.** The profile does not name it; the hook does, as its
  body. Without it the guardrail does not fire, and a guardrail that does not fire
  fails silently.
- **A workflow's agents.** A workflow names no agents: it names **roles**, and the
  project decides who fills them. Without the candidates, the other side is left
  asking for roles that do not exist there.

What the package names but no longer exists on this side **is stated** before
exporting. It is not an error — you deleted a skill a profile still mentions — but
it will be missing on the other side anyway, and silently would be worse.

## What NEVER travels

**A secret's value.** Not even when the exporter would like to send it. The names
travel, taken from the tools (which receive them as environment variables) and
from the MCP servers (`secretEnv` and the `{{PLACEHOLDER}}`s in their headers),
and the manifest declares them so the other side knows what has to be created.

Working directories, sessions, and threads do not travel either: the catalog's
portable shape already guarantees that, and it is the same one the other two
backups use ([`catalog_shape`](../../lib/src/integrations/catalog_shape/)).

## The zip

```
manifest.json            keelBundle, kind, name, summary, requiredSecrets, counts
README.md                for whoever opens it in Finder before installing
catalog/<category>/<name>.json
knowledge/<base>/<path>
```

The manifest is designed so that **a public catalog can list a package without
opening it or trusting its content**: name, type, summary, how many things it
brings, and which secrets it asks for, all on the cover.

The bytes are **deterministic** — sorted entries, a fixed date — so the same
package always produces the same file. That allows comparing it by hash, and
meanwhile prevents exporting twice from producing two different files when nothing
changed.

## The review, which is the point

What comes in is going to run on your machine and was written by somebody who is
not you. Before anything is installed, the package is opened and reviewed whole.

| What is looked for | Where | Example |
|---|---|---|
| dangerous commands | tools, hooks, MCPs **and texts** | piping a download into a shell, privilege escalation, `/dev/tcp/`, `~/.ssh`, `launchctl` |
| personal paths | everything | `/Users/someone/…`, `C:\Users\…` |
| prompt injection | prompts, skills, rules, steps, documents | "ignore the instructions", "don't tell the user" |
| text that is not visible | everything | zero-width characters, direction overrides, HTML comments |
| outbound network | tools, hooks, MCPs, texts | any host that is not local |
| power over your keel | profiles | `canManageSystem` |

Three decisions shape this:

1. **The command patterns run over the texts too.** A skill telling the agent to
   pipe a downloaded script straight into a shell ends up in the same place as a
   script, only by way of a helpful model.
2. **A hook weighs more than a tool.** A tool is called by the agent when it
   decides; a hook is fired by the CLI on its own, on every turn matching its
   event. Which is why every hook is a high-severity finding simply for existing.
3. **Every finding shows the exact fragment.** An alert without the text that
   triggered it forces you to trust the app, and trusting without being able to
   look is precisely what this feature exists to avoid.

**A "clean" package is not a safe package**, and the screen says so in those
words: a pattern matcher finds the known. What the review does guarantee is that
nothing is installed without a prior listing of what runs, what it reads, and
where it writes.

With a high-severity finding, **Install starts disabled** until you tick that you
read it. It is not an obstacle: it is the second needed to look at what is above,
which is the whole reason for having listed it. Discarding the package clears the
tick — what you read was the previous one.

## Exporting is reviewed too

The same review runs over **your own** package before it is written. It is the only
opportunity to find out that your tool carries your personal folder inside
**before** sending it to somebody; afterward it has already travelled.

That is why exporting is two steps and not one: it is prepared and shown, and only
then is the destination chosen.

## From a link

The panel also fetches a package from a URL. It is the path a public catalog would
use, and what comes down goes through the **same** review as a file chosen by hand:
the origin does not change what is inside.

On the import side there are three cutoffs before anything is looked at:

- `http` and `https` only, with a timeout;
- **64 MB** cap, counting what decompresses — a zip that expands to gigabytes is
  the cheapest way to take down somebody else's app;
- an entry whose path escapes its folder (`zip slip`) aborts the whole opening. No
  legitimate package needs it.

## Installing is the same merge as always

A package is applied with `mergeCatalogJson`, exactly like restoring a backup: it
creates or updates **by name**. There is no second entry path into the catalog to
keep in sync with the first.

Knowledge documents are written into whatever folder the base has on this side. A
freshly created base arrives **with no folder** — paths never travel — so its
documents wait, and the screen says which ones and what to do.

## Where it lives

| What | Where |
|---|---|
| The cover and the content | `integrations/catalog_bundle/src/bundle_manifest.dart` |
| What travels, pure | `src/bundle_closure.dart` |
| The zip | `src/bundle_archive.dart` |
| The review, pure | `src/bundle_audit.dart` |
| The job that crosses to another isolate | `src/bundle_job.dart` |
| Exporting and importing | `src/bundle_viewmodel.dart` |
| The two panels | `src/ui/` |

Building the zip and reviewing it run **in another isolate**, like the backup
([F27](27-startup-and-waiting.md)): reading folders, compressing at the best
compression level, and running twenty regular expressions over every text is not
between-two-frames work.

### The isolate is not called from inside a method

`Isolate.run(() => f(x))` written inside a method captures that method's CONTEXT,
and in that context is `this` — even though the line does not name it. If that
`this` is a ViewModel, its listeners lead to the widget tree, the tree has a
`FocusNode`, and the copy blows up with fifty lines of
`<- _child in Instance of ...` that never once name the culprit.

That is why the four places crossing to another isolate — the backup, the package's
zip, the review, and scanning a knowledge base — go through
`shared/utils/off_thread.dart`, which is a top-level function: there is no `this`
to capture there, and the function and its argument travel, which is all that was
needed.

## Verification

1. Export an agent with a hook, a tool, and a base → the zip carries the hook's
   tool, which the profile does not name.
2. Export a workflow → it carries each role's agents, with their own.
3. Export something with a broken reference → it is named before saving.
4. Open it in Finder → the README says what it is and which secrets it asks for.
5. Import it on another machine → the agent is identical, except the secrets, which
   are requested by name.
6. Import a package that pipes a download into a shell inside a skill → high
   severity, with the fragment, and Install disabled.
7. Any random zip → it says so in words, not with the decompressor's error.
8. A zip with `../../etc/something` inside → it does not open.
9. Export twice without changing anything → identical bytes.

## See also

- [F20](20-single-file-backup.md) and [F21](21-system-vault.md), the other two
  backups and why this is neither of them.
- [F5](05-external-mcps.md), where the secrets a package asks for come from.
