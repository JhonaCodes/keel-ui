#!/usr/bin/env bash
# Xcode Runner build phase: embed the shared local model in Debug and Release.
set -euo pipefail

DEST="${1:-}"
[[ "$DEST" == *.app/Contents/Resources ]] || {
  echo "Usage: scripts/embed_litert_model.sh <Keel.app>/Contents/Resources" >&2
  exit 64
}

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CORE_DIR="$ROOT_DIR/../keel-core"
MODEL_FILES=(
  Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.litertlm
)
NATIVE_SOURCE="$CORE_DIR/native/macos_arm64"
WORKER_OUT="$ROOT_DIR/build/litert_worker"
WORKER_SOURCE="$CORE_DIR/bin/litert_worker.dart"
WORKER_BINARY="$WORKER_OUT/bundle/bin/litert_worker"

# The local model is optional. Without it nothing is embedded, and a copy
# an earlier build left goes too: the app offers LiteRT only when it finds one.
for model_file in "${MODEL_FILES[@]}"; do
  [[ -f "$CORE_DIR/model/$model_file" ]] && continue
  rm -f "$DEST/model/$model_file" "$DEST/model/$model_file".xnnpack_cache_*
  echo "LiteRT model not installed ($CORE_DIR/model/$model_file): not embedded"
  exit 0
done
[[ -f "$NATIVE_SOURCE/libLiteRtLm.dylib" ]] || {
  echo "Missing LiteRT native libraries. Run 'dart run litert_dart:fetch_natives' in keel-core." >&2
  exit 66
}
[[ -f "$WORKER_SOURCE" ]] || {
  echo "Missing LiteRT worker source: $WORKER_SOURCE" >&2
  exit 66
}

DART=dart
[[ -n "${FLUTTER_ROOT:-}" ]] && DART="$FLUTTER_ROOT/bin/dart"
if [[ ! -x "$WORKER_BINARY" || "$WORKER_SOURCE" -nt "$WORKER_BINARY" || "$CORE_DIR/pubspec.yaml" -nt "$WORKER_BINARY" ]]; then
  [[ -f "$CORE_DIR/.dart_tool/package_config.json" ]] || (cd "$CORE_DIR" && "$DART" pub get)
  (cd "$CORE_DIR" && "$DART" build cli -t bin/litert_worker.dart -o "$WORKER_OUT")
fi

NATIVE_DEST="$DEST/native/macos_arm64"
WORKER_DEST="$DEST/litert/bin/litert_worker"
mkdir -p "$DEST/model" "$NATIVE_DEST" "$(dirname "$WORKER_DEST")"
rm -f "$DEST/model/gemma-4-E2B-it.litertlm" "$DEST/model"/gemma-4-E2B-it.litertlm.xnnpack_cache_*

# Keep iterative builds fast while still replacing a changed model.
for model_file in "${MODEL_FILES[@]}"; do
  model_source="$CORE_DIR/model/$model_file"
  model_dest="$DEST/model/$model_file"
  if [[ ! -f "$model_dest" ]] || ! cmp -s "$model_source" "$model_dest"; then
    cp "$model_source" "$model_dest"
  fi
done
for library in "$NATIVE_SOURCE"/*.dylib; do
  target="$NATIVE_DEST/$(basename "$library")"
  if [[ ! -f "$target" ]] || ! cmp -s "$library" "$target"; then
    cp "$library" "$target"
  fi
done
if [[ ! -f "$WORKER_DEST" ]] || ! cmp -s "$WORKER_BINARY" "$WORKER_DEST"; then
  cp "$WORKER_BINARY" "$WORKER_DEST"
  chmod +x "$WORKER_DEST"
  codesign --force --sign - "$WORKER_DEST"
fi

echo "LiteRT model, worker and native libraries embedded in $DEST"
