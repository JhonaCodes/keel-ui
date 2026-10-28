#!/usr/bin/env bash
# Build the stdio MCP worker a desktop client (ChatGPT desktop) launches to
# work on the Keel catalog. Prints the absolute path of the executable.
#
# `dart build cli` and not `dart compile exe`: this package pulls in
# `objective_c`, which has build hooks, and `dart compile exe` refuses those.
# Same reason and same layout as the LiteRT worker.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKER_OUT="$ROOT_DIR/build/catalog_mcp_worker"
WORKER_BINARY="$WORKER_OUT/bundle/bin/catalog_mcp_worker"

cd "$ROOT_DIR"

# The bundle carries sibling assets (objective_c.dylib) next to the binary,
# so a stale one cannot be reused: it is rebuilt whole.
rm -rf "$WORKER_OUT"
dart build cli -t bin/catalog_mcp_worker.dart -o "$WORKER_OUT" >&2

[[ -x "$WORKER_BINARY" ]] || {
  echo "build finished but $WORKER_BINARY is not there" >&2
  exit 1
}

# Only the path on stdout, so this can be used in a shell substitution.
echo "$WORKER_BINARY"
