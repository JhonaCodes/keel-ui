#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$PWD/test/agents/fixtures/codex_cli:$PATH"
export SHELL=''
export KEEL_FAKE_CODEX_CHAT=1
KEEL_CODEX_ARGV_LOG="$(mktemp -t keel-codex-argv)"
export KEEL_CODEX_ARGV_LOG
trap 'rm -f "$KEEL_CODEX_ARGV_LOG"' EXIT
export TZ=UTC
flutter test --no-pub test/agents/agent_codex_gate_test.dart test/agents/codex_model_catalog_test.dart
