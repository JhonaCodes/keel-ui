# F4 — Secrets hidden from the LLM

## What it is

A registry of keys and credentials (`Secret{name, description, value}`) whose
VALUES never pass through a model:

- The UI always masks them (`••••`, with no reveal button; the form is
  write-only: when editing, empty = keep the current value).
- They are injected as environment variables ONLY into deterministic processes:
  tool scripts (`Tool.secretNames` → `ToolExecutionService.run(environment:)`)
  and, since F5, external MCP servers. NEVER into the agent's CLI (an agent with
  Bash would run `echo $X` and the value would enter the model).
- The name follows environment-variable format (`^[A-Z][A-Z0-9_]{0,63}$`).

## The "pending" flow

An agent (Keel AI or a builder) can REQUEST that a key exist with
`request_secret(name, why)`: it is created without a value, marked **pending**,
with a record of who asked. Only the user loads the value. A tool whose declared
secrets are pending fails CLOSED with an actionable message (it never runs with
the variable absent). `list_secret_names` lists names plus state, never values.

## The form: name and value, nothing else

The name IS the environment variable, so the field says so literally
("Environment variable name", with `LINEAR_API_KEY` as the example). The form
also used to have a "What it is for" field that, read on screen, looked like a
second name box: what happened is that the real name ended up in there and the
secret got registered as `APIKEY`. That input no longer exists.
`Secret.description` remains in the model — it is where an agent explains why it
requested the key (`request_secret(why)`) — and is shown as read-only context
("Requested for: …"), never as a field to fill in.

A secret that ALREADY has a value does not show an empty input (which reads as
"not saved"): it shows `Value loaded ••••••••` with a "Replace" button that only
then opens the field. Masked, but visibly present.

## Where the value is loaded

There is ONE credential form (`SecretFormScreen`) and every surface routes to
it, so "I have the key but I don't know where it goes" has nowhere to happen:

- The Secrets screen (key icon on the rail): the full registry.
- `SecretMultiSelect` — the "Secrets (env)" section of the tool and MCP forms:
  the same row that grants the secret **loads** it when pending ("Load value"
  button), **changes its value** when it already has one, and **deletes** it
  (shared confirmation, `confirmDeleteSecret`); deleting also releases the grant
  in the open form.

Before saving, the picker warns which checked secrets will NOT be injected: the
**pending** ones (value missing) and the **missing** ones (a grant left hanging
from a deleted secret, with an action to release it). In the MCP integrations
list, `PendingSecretsBadge` marks "key missing" on an MCP that declares an
unresolved secret — the difference between registered and usable is visible
without opening the form.

## `ps` leak prevention

Since this feature, the `--mcp-config` of EVERY turn (1:1 and projects) is
written to a temporary FILE in a 0700 directory and the path is passed to the
CLI, instead of inline JSON in argv (visible in `ps`). The directory is deleted
when the turn ends. This applies in `ClaudeCliService` and in the task_runner
isolate.

## Storage

Local LMDB (prefix `secret_`), the same storage as the rest of the catalog.
Secrets NEVER enter the portable catalog, and their VALUES never enter the vault
(F21) — only the single-file backup, with an opt-in (F20). `Secret.toString()`
does not print the value.
