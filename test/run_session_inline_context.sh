#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$PWD/test/projects/fixtures/context_cli:$PATH"
export SHELL=''
export KEEL_FAKE_CONTEXT=1
export TZ=UTC
flutter test --no-pub test/projects/session_inline_context_process_test.dart
