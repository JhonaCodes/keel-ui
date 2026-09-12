#!/usr/bin/env bash
# Real dpkg/tar regression check with a tiny ELF fixture, no Flutter required.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
mkdir -p "$WORK_DIR/scripts" "$WORK_DIR/assets" "$WORK_DIR/bundle/lib"
cp "$ROOT_DIR/scripts/package_linux_release.sh" "$ROOT_DIR/scripts/release_metadata.py" \
  "$ROOT_DIR/scripts/linux_runtime.py" "$WORK_DIR/scripts/"
cp "$ROOT_DIR/assets/icon.png" "$WORK_DIR/assets/"
cp "$ROOT_DIR/LICENSE" "$WORK_DIR/"
printf 'version: 1.2.3+44\n' > "$WORK_DIR/pubspec.yaml"
printf 'int db_value(void) { return 42; }\n' > "$WORK_DIR/db.c"
printf 'extern int db_value(void); int plugin_value(void) { return db_value(); }\n' > "$WORK_DIR/plugin.c"
printf 'extern int db_value(void); extern int plugin_value(void); int main(void) { return db_value() == 42 && plugin_value() == 42 ? 0 : 1; }\n' > "$WORK_DIR/main.c"
clang -shared -fPIC -Wl,-soname,liboffline_first_core.so \
  "$WORK_DIR/db.c" -o "$WORK_DIR/bundle/lib/liboffline_first_core.so"
clang -shared -fPIC -Wl,-soname,libfixture_plugin.so \
  "$WORK_DIR/plugin.c" -L"$WORK_DIR/bundle/lib" -loffline_first_core \
  "-Wl,-rpath,\$ORIGIN/lib" -o "$WORK_DIR/bundle/lib/libfixture_plugin.so"
clang "$WORK_DIR/main.c" -L"$WORK_DIR/bundle/lib" -lfixture_plugin -loffline_first_core \
  "-Wl,-rpath,\$ORIGIN/lib" -o "$WORK_DIR/bundle/keel"
bash "$WORK_DIR/scripts/package_linux_release.sh" "$WORK_DIR/bundle" "$WORK_DIR/out"
DEB="$WORK_DIR/out/keel_1.2.3_amd64.deb"
[[ "$(dpkg-deb -f "$DEB" Architecture)" == amd64 ]]
[[ "$(dpkg-deb -f "$DEB" Version)" == 1.2.3 ]]
[[ "$(dpkg-deb -f "$DEB" Depends)" == *libc6* ]]
mkdir -p "$WORK_DIR/unpacked" "$WORK_DIR/portable"
dpkg-deb -x "$DEB" "$WORK_DIR/unpacked"
test -f "$WORK_DIR/unpacked/usr/share/applications/keel.desktop"
test -f "$WORK_DIR/unpacked/opt/keel/lib/liboffline_first_core.so"
"$WORK_DIR/unpacked/opt/keel/keel"
tar -xzf "$WORK_DIR/out/Keel-1.2.3-linux-x64.tar.gz" -C "$WORK_DIR/portable"
"$WORK_DIR/portable/keel/keel"
test -f "$WORK_DIR/portable/keel/LICENSE.txt"
if [[ $# -eq 1 ]]; then
  mkdir -p "$1"
  cp "$DEB" "$1/"
fi
rm "$WORK_DIR/bundle/lib/liboffline_first_core.so"
if bash "$WORK_DIR/scripts/package_linux_release.sh" "$WORK_DIR/bundle" "$WORK_DIR/incomplete"; then
  echo 'Packaging accepted a missing database library.' >&2
  exit 1
fi
test ! -d "$WORK_DIR/incomplete"
echo 'Linux packaging regression checks passed.'
