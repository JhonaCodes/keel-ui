#!/usr/bin/env bash
# Runs the real `codex` binary against in-process fakes (model provider and
# MCP server). CODEX_HOME is a throwaway dir: the user's ~/.codex, login and
# account are never touched.
set -euo pipefail
cd "$(dirname "$0")/.."
CODEX_HOME="$(mktemp -d -t keel-codex-home)"
export CODEX_HOME
trap 'rm -rf "$CODEX_HOME"' EXIT
export KEEL_REAL_CODEX=1
export TZ=UTC
flutter test --no-pub test/llm/codex/codex_real_binary_test.dart "$@"
