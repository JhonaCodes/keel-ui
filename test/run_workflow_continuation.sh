#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$PWD/test/projects/fixtures/continuation_cli:$PATH"
export SHELL=''
export KEEL_FAKE_WORKFLOW=1
export TZ=UTC
flutter test --no-pub test/projects/workflow_continuation_process_test.dart
