#!/usr/bin/env bash
# One local entry point for a signed, monitored GitHub release.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
exec python3 scripts/deploy_release.py "$@"
