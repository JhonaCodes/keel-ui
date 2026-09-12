#!/usr/bin/env bash
# Run as root in a fresh Ubuntu 22.04 container, separate from the build host.
set -euo pipefail
[[ $# -eq 1 && -f "$1" ]] || { echo 'Pass the .deb to verify.' >&2; exit 64; }
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends "$1" file binutils
[[ -x /opt/keel/keel && -f /opt/keel/lib/liboffline_first_core.so ]]
[[ -f /usr/share/applications/keel.desktop && -f /usr/share/pixmaps/keel.png ]]
[[ "$(dpkg-query -W -f='${Architecture}' keel)" == amd64 ]]
launcher_dependencies="$(ldd /opt/keel/keel)"
if [[ "$launcher_dependencies" == *'not found'* ]]; then
  printf 'Unresolved launcher dependencies:\n%s\n' "$launcher_dependencies" >&2
  exit 1
fi
while IFS= read -r -d '' candidate; do
  if file -b "$candidate" | grep -q '^ELF'; then
    file -b "$candidate" | grep -q 'x86-64'
    # Plugins share libraries already loaded by the launcher. Resolve those
    # from the bundle while inspecting each plugin outside that process.
    dependencies="$(LD_LIBRARY_PATH=/opt/keel/lib ldd "$candidate")"
    if [[ "$dependencies" == *'not found'* ]]; then
      printf 'Unresolved dependencies in %s:\n%s\n' "$candidate" "$dependencies" >&2
      exit 1
    fi
  fi
done < <(find /opt/keel -type f -print0)
dpkg-query -W -f='Verified ${Package} ${Version}: ${Depends}\n' keel
