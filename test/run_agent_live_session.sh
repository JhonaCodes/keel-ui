#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$PWD/test/agents/fixtures/live_cli:$PATH"
export SHELL=''
export KEEL_FAKE_LIVE_CLI=1
export TZ=UTC
flutter test --no-pub test/agents/agent_live_session_test.dart
