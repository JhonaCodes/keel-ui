# F28 — The integrations catalog, and being able to test them

## Problem it solves

Registering an external MCP was already possible (F5). What was not possible was
**knowing what exists** or **whether what you registered comes up**.

The screen opened by telling you that you had registered nothing — information
you already had — and left you with an empty form asking for a command, some
space-separated arguments, and a `KEY=VALUE` textarea. It works if you already
know what goes in. It does not help you if you do not.

And on the other side: a misconfigured MCP does not warn you. You find out three
turns later, when the agent "did not use the tool", with no way to tell whether it
chose not to or never had it.

## Three things that did not exist

### The catalog

`lib/src/integrations/mcp_catalog/` — pure data, no Flutter and no network.
Fourteen integrations with their exact configuration, their category, which
credential each one asks for, and a link to its official documentation.

The glyph is **two letters over a color from the members palette**, not the
service's logo. A logo would have to be downloaded or bundled, it goes stale when
the brand changes, and an app that promises not to reach the network on its own
should not do so to draw an icon.

**The seed is not the source of truth, and the design assumes it.** Third-party
servers' commands and URLs change without notice, and this file finds out when
somebody updates it. Hence: a visible link to the documentation, everything
editable after installing, and what follows.

### Pasting the config

Hooks had an importer (F22) and MCPs did not, so you had to translate by hand,
field by field, the `mcpServers` block every server publishes in its README.

Now you paste it and it registers, with a preview before anything is written. That
is what makes the catalog robust against going stale: if an entry lies, the
documentation's version wins.

The importer warns when an `env` carries a credential inside. And it does not look
only at the key's name, because the most common case does not announce itself:
`DATABASE_URL` has not a single suspicious word and carries the database password
written out. It is also detected by the SHAPE of the value — a connection string
with `user:password@`.

### Testing

`lib/src/integrations/mcp_probe/` performs the same handshake the CLI does:
`initialize`, `notifications/initialized`, `tools/list`. What it returns is what
the agent will see.

| Transport | How |
|---|---|
| stdio | `Process.start` plus `dart_mcp`'s channel, and `kill()` in a `finally` |
| http / sse | JSON-RPC by hand over `package:http`, reading `Mcp-Session-Id` and SSE responses |

`dart_mcp` ships a stdio channel but not an HTTP one. It is three messages and the
protocol is published: writing them here came out cheaper than dragging in another
dependency.

The result is stored in **a separate record** (`mcpprobe_<id>`) and **does not
travel in the backup**. It is this machine's state at this moment, not
configuration: restoring on another machine a "connected, 42 tools" that was never
verified there would be a tidy lie. Same criterion as the roadmap's task claims
(F23).

Editing a server **deletes its probe**: the configuration changed, so what it
answered last time no longer describes it.

## A secret inside a header

The hole left in the model: a remote server could not take its token from a
secret, because `headers` travelled as plain text. And the three most used remotes
— GitHub, Linear, Sentry — are exactly that: a URL and an `Authorization: Bearer`.

A header's value can now reference `{{NAME}}` and is resolved when building the
turn, inside `--mcp-config`'s temporary file. It is a template and not a
key→secret map because the secret is almost never the whole value:
`Authorization` needs `Bearer ` in front.

**If the secret is missing, the whole header is omitted.** Half-resolved is worse
than absent: an `Authorization: Bearer ` with nothing behind it makes the server
answer 400 where the absent header answered a legible 401.

## The honest limit: OAuth

Every turn runs with `--strict-mcp-config`, which tells the CLI to use **only**
the file we hand it and ignore the user's global configuration. That is what keeps
one project from inheriting another's MCPs.

The price: a server you authenticated outside with `claude mcp add` **is not
visible from Keel**. Removing that flag would fix one case and break everyone's
isolation.

So the entries that require OAuth say so, and a test enforces it: an entry marked
`oauth` without a note fails the suite. The way out, when the service offers one,
is an API token in the header — and the probe confirms it in two seconds instead
of in three turns.

## Keel AI

`list_mcp_catalog` and `install_mcp_integration` exist for one concrete reason: so
that when you ask for "I want Linear" it does not invent an npm package name. It
reads the entry, registers the exact configuration, and tells you which secret is
missing.

The secret's VALUE never passes through the model: the tool leaves the reference
in place and the "key missing" badge appears on its own.

## Verification

1. Install Linear from the catalog → the form opens filled in, with the credential
   explained and the link to its documentation.
2. Create the secret right there → the name comes suggested.
3. **Test** → the real list of tools. Delete the secret's value → it fails and
   says which one is missing, without trying to connect.
4. An OAuth server with no token → 401, with what to do about it written out.
5. Paste a `{"mcpServers": {...}}` with three servers → all three registered;
   names already taken appear as replacements.
6. Paste one with `DATABASE_URL` carrying a password → it flags it.
7. Assign the integration to an agent and run a turn: its tools arrive.
8. Export the backup → the integration travels, its probe does not.
