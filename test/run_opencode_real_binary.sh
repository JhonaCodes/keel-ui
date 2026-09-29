#!/usr/bin/env bash
# Real `opencode` with a free model: needs network, spends no paid tokens.
set -euo pipefail
cd "$(dirname "$0")/.."
export KEEL_REAL_OPENCODE=1
export TZ=UTC
flutter test --no-pub test/llm/opencode_real_binary_test.dart "$@"
