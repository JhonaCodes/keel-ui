#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$PWD/test/agents/fixtures/chat_cli:$PATH"
export SHELL=''
export KEEL_FAKE_CHAT=1
# A 1:1 chat runs its CLI in $HOME: the fixtures log here instead.
KEEL_FAKE_DIR="$(mktemp -d)"
export KEEL_FAKE_DIR
trap 'rm -rf "$KEEL_FAKE_DIR"' EXIT
export TZ=UTC
flutter test --no-pub test/agents/chat_send_now_process_test.dart
