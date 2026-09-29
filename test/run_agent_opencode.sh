#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$PWD/test/agents/fixtures/opencode_cli:$PATH"
export SHELL=''
export KEEL_FAKE_OPENCODE=1
KEEL_OPENCODE_LOG="$(mktemp -t keel-opencode-log)"
export KEEL_OPENCODE_LOG
trap 'rm -f "$KEEL_OPENCODE_LOG"' EXIT
export TZ=UTC
flutter test --no-pub test/agents/agent_opencode_test.dart
