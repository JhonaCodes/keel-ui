#!/usr/bin/env bash
# Package an existing, versioned Flutter Linux release bundle on Ubuntu 24.04.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_DIR="${1:-$ROOT_DIR/build/linux/x64/release/bundle}"
OUTPUT_DIR="${2:-$ROOT_DIR/build/release}"
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || {
  echo 'Linux releases require a native Linux x86_64 toolchain.' >&2
  exit 65
}
for tool in python3 dpkg-deb dpkg-shlibdeps file readelf tar; do
  command -v "$tool" >/dev/null || { echo "Missing $tool" >&2; exit 69; }
done
[[ -x "$BUNDLE_DIR/keel" && -f "$BUNDLE_DIR/lib/liboffline_first_core.so" ]] || {
  echo 'Incomplete bundle: keel and lib/liboffline_first_core.so are required.' >&2
  exit 66
}
[[ ! -e "$BUNDLE_DIR/lib/libdartjni.so" ]] || {
  echo 'Unexpected desktop JNI library. Rebuild with the tracked Linux CMake configuration.' >&2
  exit 66
}
VERSION="$(python3 "$ROOT_DIR/scripts/release_metadata.py" --pubspec "$ROOT_DIR/pubspec.yaml" |
  python3 -c 'import json,sys; print(json.load(sys.stdin)["version"])')"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
STAGE_DIR="$WORK_DIR/package"
mkdir -p "$STAGE_DIR/opt/keel" "$STAGE_DIR/DEBIAN" \
  "$STAGE_DIR/usr/bin" "$STAGE_DIR/usr/share/applications" \
  "$STAGE_DIR/usr/share/pixmaps" "$STAGE_DIR/usr/share/doc/keel"
cp -a "$BUNDLE_DIR/." "$STAGE_DIR/opt/keel/"
cp "$ROOT_DIR/LICENSE" "$STAGE_DIR/usr/share/doc/keel/copyright"
cp "$ROOT_DIR/assets/icon.png" "$STAGE_DIR/usr/share/pixmaps/keel.png"
ln -s /opt/keel/keel "$STAGE_DIR/usr/bin/keel"
cat > "$STAGE_DIR/usr/share/applications/keel.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Keel
Comment=Workspace for coding agents
Exec=keel
Icon=keel
Terminal=false
Categories=Development;IDE;
StartupWMClass=com.jhonacode.keelUi
DESKTOP

# Include every native library, not just the executable: plugins may require
# a newer glibc or another runtime package than the Flutter runner itself.
ELF_ARGS=()
while IFS= read -r -d '' candidate; do
  if file -b "$candidate" | grep -q '^ELF'; then
    file -b "$candidate" | grep -q 'x86-64' || {
      echo "Wrong architecture: $candidate" >&2
      exit 67
    }
    ELF_ARGS+=("-e$candidate")
  fi
done < <(find "$STAGE_DIR/opt/keel" -type f -print0)
[[ ${#ELF_ARGS[@]} -gt 0 ]] || { echo 'Bundle has no ELF binaries.' >&2; exit 66; }

mkdir -p "$WORK_DIR/debian"
cat > "$WORK_DIR/debian/control" <<'CONTROL'
Source: keel
Section: devel
Priority: optional
Maintainer: JhonaCode <contact@jhonacode.com>

Package: keel
Architecture: amd64
Description: Keel coding agent workspace
CONTROL
DEPENDENCIES="$(cd "$WORK_DIR" && dpkg-shlibdeps -O --ignore-missing-info \
  -l"$STAGE_DIR/opt/keel/lib" "${ELF_ARGS[@]}")"
DEPENDENCIES="${DEPENDENCIES#shlibs:Depends=}"
DEPENDENCIES="$(python3 "$ROOT_DIR/scripts/linux_runtime.py" \
  --dependencies "$DEPENDENCIES" "${ELF_ARGS[@]#-e}")"
[[ "$DEPENDENCIES" == *libc6* ]] || {
  echo 'Could not resolve native runtime dependencies.' >&2
  exit 68
}
cat > "$STAGE_DIR/DEBIAN/control" <<CONTROL
Package: keel
Version: $VERSION
Section: devel
Priority: optional
Architecture: amd64
Maintainer: JhonaCode <contact@jhonacode.com>
Depends: $DEPENDENCIES
Homepage: https://github.com/JhonaCodes/keel-ui
Description: Keel coding agent workspace
 Desktop workspace for collaborating with coding agents.
CONTROL
chmod 755 "$STAGE_DIR" "$STAGE_DIR/DEBIAN"
chmod 644 "$STAGE_DIR/DEBIAN/control" "$STAGE_DIR/usr/share/applications/keel.desktop"
dpkg-deb --root-owner-group --build "$STAGE_DIR" "$OUTPUT_DIR/keel_${VERSION}_amd64.deb"

cp "$ROOT_DIR/LICENSE" "$STAGE_DIR/opt/keel/LICENSE.txt"
tar -czf "$OUTPUT_DIR/Keel-${VERSION}-linux-x64.tar.gz" -C "$STAGE_DIR/opt" keel
tar -tzf "$OUTPUT_DIR/Keel-${VERSION}-linux-x64.tar.gz" >/dev/null
echo "Packaged Keel $VERSION. Depends: $DEPENDENCIES"
