#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PUBSPEC_PATH="$ROOT_DIR/pubspec.yaml"
OUTPUT_DIR="${KEEL_COMPILED_DIR:-$(cd "$ROOT_DIR/.." && pwd)/compiled}"
DOWNLOAD_BASE_URL="${KEEL_DOWNLOAD_BASE_URL:-https://jhonacode.com/keel}"
DRY_RUN=false

usage() {
  echo "Uso: scripts/build_macos_release.sh [--dry-run] [--output-dir RUTA]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --output-dir)
      [[ $# -ge 2 ]] || { usage >&2; exit 64; }
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Argumento desconocido: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

for command_name in dart flutter codesign hdiutil lipo shasum; do
  command -v "$command_name" >/dev/null || {
    echo "Falta el comando requerido: $command_name" >&2
    exit 69
  }
done

CURRENT_VERSION="$(sed -nE 's/^version:[[:space:]]*([^[:space:]]+).*/\1/p' "$PUBSPEC_PATH")"
[[ -n "$CURRENT_VERSION" ]] || {
  echo "No se encontró version: en pubspec.yaml" >&2
  exit 65
}
NEXT_VERSION="$(cd "$ROOT_DIR" && dart run tool/release_version.dart next "$CURRENT_VERSION")"

[[ "$DOWNLOAD_BASE_URL" == https://* ]] || {
  echo "KEEL_DOWNLOAD_BASE_URL debe usar HTTPS." >&2
  exit 65
}

if [[ "$DRY_RUN" == true ]]; then
  echo "Versión actual: $CURRENT_VERSION"
  echo "Próxima compilación: $NEXT_VERSION"
  echo "Salida: $OUTPUT_DIR"
  exit 0
fi

mkdir -p "$OUTPUT_DIR"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/keel-release.XXXXXX")"
ORIGINAL_PUBSPEC="$WORK_DIR/pubspec.yaml"
cp "$PUBSPEC_PATH" "$ORIGINAL_PUBSPEC"
PUBLISHED=false
cleanup() {
  local status=$?
  if [[ "$PUBLISHED" != true && -f "$ORIGINAL_PUBSPEC" ]]; then
    cp "$ORIGINAL_PUBSPEC" "$PUBSPEC_PATH"
    echo "La release no terminó; se restauró la versión anterior." >&2
  fi
  for temp_path in \
    "${VERSIONED_TEMP:-}" \
    "${LATEST_TEMP:-}" \
    "${MANIFEST_TEMP:-}"; do
    [[ -n "$temp_path" && -f "$temp_path" ]] && rm -f "$temp_path"
  done
  [[ -d "$WORK_DIR" ]] && rm -r "$WORK_DIR"
  return "$status"
}
trap cleanup EXIT

RELEASE_VERSION="$(cd "$ROOT_DIR" && dart run tool/release_version.dart bump "$PUBSPEC_PATH")"
BUILD_NAME="${RELEASE_VERSION%%+*}"
BUILD_NUMBER="${RELEASE_VERSION##*+}"

echo "Compilando Keel $BUILD_NAME (build $BUILD_NUMBER)…"
BUILD_ARGS=(
  build macos --release
  "--build-name=$BUILD_NAME"
  "--build-number=$BUILD_NUMBER"
)
if [[ -f "$ROOT_DIR/keel_secrets.json" ]]; then
  BUILD_ARGS+=("--dart-define-from-file=$ROOT_DIR/keel_secrets.json")
fi
(cd "$ROOT_DIR" && flutter "${BUILD_ARGS[@]}")

APP_PATH="$ROOT_DIR/build/macos/Build/Products/Release/Keel.app"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/Keel"
[[ -d "$APP_PATH" && -f "$EXECUTABLE_PATH" ]] || {
  echo "Flutter no produjo Keel.app en la ruta esperada." >&2
  exit 66
}

codesign --force --deep --sign - "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

ARCHITECTURES="$(lipo -archs "$EXECUTABLE_PATH")"
[[ "$ARCHITECTURES" == *arm64* && "$ARCHITECTURES" == *x86_64* ]] || {
  echo "La app no es universal: $ARCHITECTURES" >&2
  exit 67
}

STAGE_DIR="$WORK_DIR/stage"
mkdir -p "$STAGE_DIR"

cp -R "$APP_PATH" "$STAGE_DIR/Keel.app"
ln -s /Applications "$STAGE_DIR/Applications"
cp "$ROOT_DIR/LICENSE" "$STAGE_DIR/LICENSE.txt"

{
  echo "KEEL $BUILD_NAME (build $BUILD_NUMBER)"
  echo
  echo "1. Arrastrá Keel.app a Applications."
  echo "2. En la primera apertura, hacé clic derecho sobre Keel y elegí Abrir."
  echo "3. Descargá actualizaciones únicamente desde jhonacode.com."
} > "$STAGE_DIR/LEEME.txt"

DMG_NAME="Keel-$BUILD_NAME-macos-universal.dmg"
TEMP_DMG="$WORK_DIR/$DMG_NAME"
VERSIONED_DMG="$OUTPUT_DIR/$DMG_NAME"
LATEST_DMG="$OUTPUT_DIR/Keel-latest-macos-universal.dmg"

hdiutil create \
  -volname "Keel $BUILD_NAME" \
  -srcfolder "$STAGE_DIR" \
  -format UDZO \
  -ov \
  "$TEMP_DMG"
hdiutil verify "$TEMP_DMG"

SHA256="$(shasum -a 256 "$TEMP_DMG" | awk '{print $1}')"
PUBLISHED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
DOWNLOAD_URL="$DOWNLOAD_BASE_URL/$DMG_NAME"
MANIFEST_SOURCE="$WORK_DIR/latest.json"
(cd "$ROOT_DIR" && dart run tool/release_version.dart manifest \
  "$RELEASE_VERSION" \
  "$DOWNLOAD_URL" \
  "$SHA256" \
  "$PUBLISHED_AT" \
  "$MANIFEST_SOURCE")

VERSIONED_TEMP="$OUTPUT_DIR/$DMG_NAME.$$.tmp"
LATEST_TEMP="$OUTPUT_DIR/Keel-latest-macos-universal.dmg.$$.tmp"
MANIFEST_TEMP="$OUTPUT_DIR/latest.json.$$.tmp"
cp "$TEMP_DMG" "$VERSIONED_TEMP"
cp "$TEMP_DMG" "$LATEST_TEMP"
cp "$MANIFEST_SOURCE" "$MANIFEST_TEMP"
mv "$VERSIONED_TEMP" "$VERSIONED_DMG"
mv "$LATEST_TEMP" "$LATEST_DMG"
mv "$MANIFEST_TEMP" "$OUTPUT_DIR/latest.json"
PUBLISHED=true

echo
echo "Release lista: $VERSIONED_DMG"
echo "Alias reemplazado: $LATEST_DMG"
echo "Manifiesto: $OUTPUT_DIR/latest.json"
echo "SHA-256: $SHA256"
