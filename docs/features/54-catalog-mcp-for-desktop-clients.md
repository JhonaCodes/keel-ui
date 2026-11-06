# F54 — The catalog as a local MCP server for desktop clients

## What it is

A worker process a third-party desktop MCP client — ChatGPT desktop — launches
over **stdio** to read and write the Keel catalog: skills, rules, hooks, tools,
workflows, projects, agents, MCP servers, knowledge bases.

The point of product: **ChatGPT is the worker, not the launcher.** It reads a
whole skill, a whole workflow contract, a whole knowledge document, and edits
the catalog itself with deterministic tools on the host. It never opens a
session and never spends Keel model credit — there is no tool for that.

## How it is wired, and why it is a relay

The worker does **not** boot its own stores. It speaks MCP on stdio and
forwards each message to the catalog MCP server the running app already
exposes on loopback (`KeelCoreRuntime.start` → `CatalogMcpServer.ensureStarted`).

Two facts forced that, and both are worth keeping written down:

1. The app's storage backend is `flutter_local_db`, whose Dart API re-exports
   `path_provider` → `package:flutter/foundation.dart` → `dart:ui`. A binary
   built without the Flutter engine **cannot compile against it**, and there is
   no way to import only its FFI half.
2. Even with an engine, a second process writing the same LMDB loses data:
   `LocalDatabase` reads the whole database into memory once, and
   `replaceAllWithPrefix` decides what to delete by comparing against that
   cached index. Anything the worker wrote would be silently overwritten by the
   app.

The relay turns that constraint into the better behaviour: it is not "the same
database", it is **the same live stores**. A skill created from ChatGPT shows
up in keel-ui immediately, with no restart.

The price, stated plainly: **Keel has to be open.** When it is not, the worker
answers a JSON-RPC error saying so instead of hanging.

### The handoff file

The catalog server takes an ephemeral port and a fresh token on every launch,
and the worker is launched by ChatGPT — there is nothing to inherit. So the app
writes `catalog_mcp_endpoint.json` (mode 0600; it holds a token that opens the
whole catalog) into its application-support directory, and the worker is handed
that absolute path in its `args`. The worker never guesses where the app keeps
its data.

## The boundary with `assistant_mcp`

| | `assistant_mcp` (`keelai-actions`) | this (`keel-catalog`) |
|---|---|---|
| Who talks to it | Keel's own in-app assistant | an external desktop client |
| Transport | HTTP on loopback, one route per agent | stdio, via the worker |
| Opens sessions | yes (`open_project_session`, `intervene`, `reply_in_session`) | **no** |

A desktop client never touches `assistant_mcp`. The HTTP token in Settings is
not the path for ChatGPT desktop.

## Install

1. Build the worker once:

   ```bash
   ./scripts/build_catalog_mcp_worker.sh
   ```

   It prints the absolute path of the executable. The binary needs the sibling
   files `dart build cli` puts next to it, so **do not move it out of its
   `bundle/` folder** — point the client at it where it is.

2. Open Keel → Settings → **Catalog for ChatGPT desktop**, and copy the block.
   It is generated from what actually exists on this machine, so the paths are
   real:

   ```json
   {
     "mcpServers": {
       "keel-catalog": {
         "command": "/abs/path/keel-ui/build/catalog_mcp_worker/bundle/bin/catalog_mcp_worker",
         "args": [
           "--endpoint",
           "/Users/<you>/Library/Application Support/com.jhonacode.keelUi/catalog_mcp_endpoint.json"
         ]
       }
     }
   }
   ```

   If the section says the worker is not built yet, run step 1 and press
   **Check again** — no restart needed.

3. Paste it into ChatGPT desktop's MCP configuration and reconnect.

A release build resolves the worker from `…/Keel.app/Contents/Resources/catalog_mcp/bin/`
first; bundling it into the signed `.app` is not done yet, so today this is the
from-source path.

## Verify by hand

With Keel open:

```bash
ENDPOINT="$HOME/Library/Application Support/com.jhonacode.keelUi/catalog_mcp_endpoint.json"
WORKER="$(pwd)/build/catalog_mcp_worker/bundle/bin/catalog_mcp_worker"

printf '%s\n%s\n%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"smoke","version":"1"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  | "$WORKER" --endpoint "$ENDPOINT"
```

Expect two JSON lines: the `initialize` result naming `keel-catalog`, and the
tool list with `list_catalog`, `get_item`, `create_skill`, `create_workflow`,
`create_project` and friends — and no `open_project_session`.

End to end: ask ChatGPT to create a skill with `create_skill`, then look at the
skills list in keel-ui. It is there without restarting.

Close Keel and run the same snippet: the reply is a JSON-RPC error telling you
to open the app.
