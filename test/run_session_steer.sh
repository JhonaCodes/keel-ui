#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$PWD/test/projects/fixtures/steer_cli:$PATH"
export SHELL=''
export KEEL_FAKE_STEER=1
export TZ=UTC
flutter test --no-pub test/projects/session_steer_process_test.dart
