#!/usr/bin/env bash
# Builds the keel-e2e engine and copies it into a Keel build together with
# its ONNX Runtime library and its OCR models, so the E2E tab works with
# nothing installed apart from Keel. The macOS build phase "Embed keel-e2e"
# runs it on every build, debug or release:
#
#   scripts/embed_keel_e2e.sh <Keel.app>/Contents/Resources/keel_e2e
#
# keel-e2e lives next to keel-ui, the same checkout pubspec.yaml already
# needs for keel_e2e_panel. The engine is rebuilt only when its sources
# change; the models are downloaded once, pinned by sha256, into
# build/keel_e2e. A build from a clean build/ therefore needs the network
# (pub get, ONNX Runtime, Hugging Face), and any failure here fails the Keel
# build instead of shipping a Keel without its engine.

set -euo pipefail

# The destination is wiped before the copy, so only an app bundle's
# resources folder is accepted.
DEST="${1:-}"
[[ "$DEST" == *.app/Contents/Resources/keel_e2e ]] || {
  echo "Usage: scripts/embed_keel_e2e.sh <App>.app/Contents/Resources/keel_e2e" >&2
  exit 64
}

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
E2E_DIR="$(cd "$ROOT_DIR/.." && pwd)/keel-e2e"
ENGINE_DIR="$E2E_DIR/packages/keel_e2e_engine"
PROTOCOL_DIR="$E2E_DIR/packages/keel_e2e_protocol"
CACHE_DIR="$ROOT_DIR/build/keel_e2e"
# `dart build cli` wipes its whole output folder, so the engine gets one of
# its own and the models stay out of it.
ENGINE_OUT="$CACHE_DIR/engine"
ENGINE_BINARY="$ENGINE_OUT/bundle/bin/keel_e2e"
MODELS_DIR="$CACHE_DIR/models/ppocrv5"
STAMP="$CACHE_DIR/engine.stamp"

DART=dart
[[ -n "${FLUTTER_ROOT:-}" ]] && DART="$FLUTTER_ROOT/bin/dart"

[[ -d "$ENGINE_DIR" ]] || {
  echo "keel-e2e is missing: it must be checked out at $E2E_DIR." >&2
  exit 66
}

engine_is_stale() {
  [[ -x "$ENGINE_BINARY" && -n "$(ls -A "$ENGINE_OUT/bundle/lib" 2>/dev/null)" \
    && -f "$STAMP" ]] || return 0
  [[ -n "$(find "$ENGINE_DIR/bin" "$ENGINE_DIR/lib" "$ENGINE_DIR/hook" \
    "$ENGINE_DIR/pubspec.yaml" "$PROTOCOL_DIR/lib" \
    "$PROTOCOL_DIR/pubspec.yaml" "$E2E_DIR/pubspec.yaml" \
    "$E2E_DIR/pubspec.lock" -newer "$STAMP" -print -quit)" ]]
}

if engine_is_stale; then
  echo "Building the keel-e2e engine…"
  mkdir -p "$CACHE_DIR"
  # Stamped before the build starts: a source saved while it compiles is
  # newer than the stamp and triggers the next rebuild.
  touch "$STAMP.next"
  (cd "$E2E_DIR" && "$DART" pub get)
  (cd "$ENGINE_DIR" && "$DART" build cli --output "$ENGINE_OUT")
  mv "$STAMP.next" "$STAMP"
fi

# Keeps the files already in place when their sha256 matches, so after the
# first build this only re-checks them.
"$ENGINE_BINARY" ocr install --models-dir "$MODELS_DIR"

rm -rf "$DEST"
mkdir -p "$DEST/models"
cp -R "$ENGINE_OUT/bundle/." "$DEST/"
cp -R "$MODELS_DIR" "$DEST/models/"
echo "keel-e2e embedded in $DEST"
