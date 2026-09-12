# Building and distributing Keel

This is not a feature: it is how what people download gets produced. It is here
because the three platforms have different constraints and none of them is
obvious, and because half the decisions below were taken after something failed.

## Where we stand

| Platform | State | Where it builds |
|---|---|---|
| macOS (arm64 + x86_64) | ✅ works | local Mac or GitHub Actions `macos-15` |
| Linux x86_64 | Ubuntu 24.04 baseline | GitHub Actions `ubuntu-24.04` |
| Linux arm64 | ❌ impossible today | — |
| Windows x64 | ❌ does not compile | — |

Both ❌ have the **same** cause, and it is not the lack of a machine.

## GitHub Actions: installers from a tag

The repository workflow is [release.yml](../.github/workflows/release.yml).
Pushing a stable tag such as `v1.2.4` builds and publishes a GitHub Release in
this repository. The tag must match the version committed in `pubspec.yaml`:
`version: 1.2.4+45` means tag `v1.2.4`, app version `1.2.4`, build `45`.
CI **does not bump or commit the version**. Update it before creating the tag.

### Deploy from this checkout

Commit your code changes on `main`, then run:

```sh
./scripts/deploy.sh --check
./scripts/deploy.sh
```

The script uses the project's existing version increment policy (patch and build,
with the patch rollover at twenty), creates a signed version commit and a **signed
OpenPGP tag**, and pushes both atomically. Starting at `1.2.4+45`, it releases
`1.2.5+46` with tag `v1.2.5`. It requires Git, GitHub CLI authenticated to the repo,
Dart, and the user's configured GPG signing key. No private key is sent to Actions.
The working tree must be clean; the script never commits unrelated changes.

It verifies the tag locally **and through GitHub**, waits for both build jobs and
publication, and downloads all assets to `build/downloads/vVERSION/`. Success means
the release is public, all expected installers exist, and their downloaded bytes
match `SHA256SUMS.txt`. Actions also checks unauthenticated public download URLs.

To choose a higher version explicitly or resume after a connection failure:

```sh
./scripts/deploy.sh --version 1.3.0
./scripts/deploy.sh --resume v1.2.5
```

Resume requires the same commit and a valid signed tag; it can finish a tag push
that did not reach GitHub or rerun failed jobs. If code needs fixing, commit the
fix and run a new deployment, which creates a new version instead of rewriting a
remote tag. `--check` validates prerequisites without committing or publishing.

Actions displays `Keel v1.2.5 · macOS + Linux · push`; GitHub's appended `#N` is
the workflow run number, not the release version. A manually created tag must use
`git tag -s`, not `git tag -a`: annotation alone does not sign a tag. The metadata
job refuses publication runs whose tag GitHub cannot verify.

Use a new version/tag for every public release. A tag mismatch, missing build
number, prerelease suffix, or malformed version stops the workflow before
compilation. Re-running a failed release can finish an existing draft; it cannot
overwrite an already published release.

### What gets published

| Asset | Purpose |
|---|---|
| `Keel-VERSION-macos-universal.dmg` | macOS installer, Apple Silicon + Intel |
| `keel_VERSION_amd64.deb` | Debian/Ubuntu x86_64 installer |
| `Keel-VERSION-linux-x64.tar.gz` | Portable Linux x86_64 bundle |
| `latest.json` | Existing macOS update manifest format, pointing to this release |
| `SHA256SUMS.txt` | SHA-256 for all four files |

The two build jobs run independently. Publishing starts only when **both** pass.
The release stays a draft while assets upload and becomes public only afterward.
Only the publish job has `contents: write`; builds have read-only repository
access. Actions are pinned to commit SHAs and Flutter to **3.44.9**, matching the
validated local toolchain. Dependency resolution enforces `pubspec.lock`.

macOS uses `scripts/build_macos_release.sh --no-bump`. It verifies the ad-hoc
signature, both architectures in the launcher, AOT framework and Flutter engine,
and the DMG checksum. It is **not notarized**; distributing a notarized app would
require Apple signing credentials and a separate notarization step.

Linux compiles on native x86_64 Ubuntu 24.04. The packaging script derives Debian
dependencies from **all** bundled ELF binaries with `dpkg-shlibdeps`, including
the database library. A fresh Ubuntu 24.04 container then installs the `.deb`
with `apt`, checks architecture, launcher/icon entries and the database library,
and checks every ELF with `ldd`. The packager also reads ELF version requirements
directly so a prebuilt plugin cannot silently understate its glibc dependency.
Any missing runtime library prevents publishing.

### Try the workflow without publishing

In GitHub, open **Actions → Build and publish installers → Run workflow** and
select the branch to build. This produces the same downloadable Actions
artifacts, retained for 14 days, but **never creates a release**, even when run
manually against a tag. Public release assets do not use that retention period.

No custom token or build secret is required. Optionally configure the Actions
secret `KEEL_BUILD_DEFINES_JSON` with the contents of `keel_secrets.json` to enable
the existing build-time error reporting configuration. It is written only during
the build and removed afterward. As explained below, values embedded into a
distributed client are recoverable from that client.

The app's existing updater still reads `https://jhonacode.com/keel/latest.json`.
Publishing a GitHub Release does **not** upload anything to that website or change
the updater URL. The manifest is included so that a separate website publishing
step can use it when desired.

### Local checks for changes to this pipeline

```sh
actionlint .github/workflows/release.yml
shellcheck scripts/build_macos_release.sh scripts/package_linux_release.sh scripts/verify_linux_release.sh test/release/test_linux_packaging.sh
python3 -m unittest discover -s test/release -p 'test_*.py'
TZ=UTC flutter test test/update/release_pipeline_contract_test.dart
```

On Linux, `bash test/release/test_linux_packaging.sh` compiles a small ELF fixture,
packages it, extracts and runs both distributions, and verifies that a missing
database library is rejected. It requires `clang`, `dpkg-dev`, `file`, and Python.
The Linux workflow runs this before building Keel itself.

## The cause: `flutter_local_db` does not cover all three

The package ships prebuilt native binaries, one per platform. What version 1.5.1
brings:

```
macos/    liboffline_first_core_arm64.dylib     ✅
          liboffline_first_core_x86_64.dylib    ✅
linux/    liboffline_first_core.so   → x86-64 and nothing else
windows/  the folder does not exist
```

From which the two consequences follow:

- **Linux arm64** compiles and then blows up on opening the database, because the
  `.so` that gets bundled is x86-64. Raspberry, ARM servers, Asahi, the cheap ARM
  cloud VMs: all of that is left out.
- **Windows does not even compile.** The package's `pubspec.yaml` **declares**
  `windows:` as a supported platform but does not ship the folder. Flutter
  generates the plugin registrant, runs `add_subdirectory` over a directory that
  does not exist, and CMake dies there. No PC fixes that.

This repository currently locks 1.5.1. Windows should be enabled only after a
dependency version with its Windows runner and native binary is validated.

## macOS

Native on the Mac. Universal: a single binary with both architectures.

The normal path is the release script, from the repo's root:

```sh
scripts/build_macos_release.sh
```

Before touching anything you can inspect which version it would produce:

```sh
scripts/build_macos_release.sh --dry-run
```

The script runs the whole flow: bumps version and build, compiles, signs, verifies
the signature and both architectures, creates and verifies the DMG, replaces
`Keel-latest-macos-universal.dmg`, and publishes into the `compiled` folder:

- `Keel-MAJOR.MINOR.PATCH-macos-universal.dmg`;
- `Keel-latest-macos-universal.dmg`;
- `latest.json`, with version, build, URL, date, and SHA-256.

The folder can be changed with `--output-dir` or `KEEL_COMPILED_DIR`. The
manifest's base URL is changed with `KEEL_DOWNLOAD_BASE_URL`; the default is
`https://jhonacode.com/keel`.

### Version rule

`pubspec.yaml` is the single source. Each automatic release increments the last
number and the build:

```text
1.4.18+41  →  1.4.19+42
1.4.19+41  →  1.5.0+42
```

The patch uses `0..19`; on reaching 20 it returns to zero and increments the minor.
The major is never incremented by the script: it is changed by hand in
`pubspec.yaml`. If compiling, signing, packaging, or the manifest fails, the script
restores the previous version and does not replace the published artifacts.

The `latest.json` manifest must be published alongside the DMG in the official
channel; without that file the app keeps its version visible, but does not invent
that an update exists.

The command below stays as a reference for diagnosing the build without the
automated packaging:

```sh
flutter build macos --release --dart-define-from-file=keel_secrets.json
```

**No `--obfuscate`, on purpose.** It was tried and dropped: it broke something
visible in the UI before contributing anything, and the real cost was not the
renamed symbol but that every stack reaching the error channel needed a manual
`flutter symbolize` against a 6 MB map that had to be archived per release. An AOT
release build is already native machine code — there is no Dart to recover — which
is rather more than the average protects.

What does stay exposed, with or without obfuscation: **the strings**. Obfuscation
renames symbols, never literals, because touching them would break every
`toString()`. The channel's webhook comes out with `strings` in five seconds.

**After compiling you have to re-sign.** It is not optional and it is expensive to
find out: if you run `flutter build` twice in a row, the second replaces the Dart
binary inside `App.framework` without re-signing the outer bundle, and the app is
left with a broken signature. Gatekeeper rejects it even if the user right-clicks →
Open.

```sh
codesign --force --deep --sign - build/macos/Build/Products/Release/Keel.app
```

And it is verified by looking at the **exit code**, not the last line of text:

```sh
if codesign --verify --deep --strict <app>; then echo OK; else echo BROKEN; fi
```

A `codesign ... | tail -1` returns `tail`'s status, which is always 0. That is how
an invalid signature slipped past us once.

The `.dmg` is assembled with `hdiutil` over a folder carrying `Keel.app`, a link to
`/Applications`, the `LICENSE.txt`, and the `LEEME.txt`.

**Ad-hoc signature, not notarized.** `spctl` rejects it, and that is expected: the
first open has to be right-click → Open. Notarizing requires a paid Apple Developer
account. It is worth it when distributing seriously: it does not prevent reverse
engineering, but it does prevent somebody from modifying the app and handing it
around signed as though it were the original — which is exactly what clause 4 of
the terms says.

## Linux

### Why it is not built on the Mac

Docker Desktop on Apple Silicon brings up **arm64** containers. The database's
`.so` is **x86-64**. Building there requires emulating amd64 with qemu: it works,
but it is slow and there is no reason to pay for it when `hp-server` exists and is
natively x86_64.

### Supported Linux baseline

The reproducible package `flutter_local_db` 1.5.1 from pub.dev includes a database
library that requires **GLIBC_2.38**. The `v1.2.4` Actions run proved that Ubuntu
22.04 cannot load it, even though the Flutter runner itself compiled successfully.
The earlier claim that building the runner on 22.04 guarantees glibc 2.34 support
was incorrect: it overlooked this prebuilt dependency.

Releases now compile on **Ubuntu 24.04 x86_64**, and installation is checked in a
separate clean Ubuntu 24.04 container. The actual maximum glibc requirement across
all binaries is included in the Debian package's dependencies. These packages do
not support Ubuntu 22.04 or Debian 12. Restoring that compatibility requires a
reproducible rebuild of the database dependency against an older glibc first.

### How it is done

The image (`ubuntu:24.04` + Flutter's toolchain + `libgtk-3-dev`) is built once and
stays cached on the server. Then, per release:

```sh
rsync -az <source> hp-server:~/keel-build/src
ssh hp-server 'docker run --rm \
  -v ~/keel-build/src:/src -v ~/keel-build/out:/out \
  keel-linux-builder:<flutter> bash /build-linux.sh'
```

The script produces a `.deb` and a portable `.tar.gz`, a flat release just like
macOS.

**The `linux/` runner lives in the repo.** The script does NOT generate it: it
validates that it is there and fails if not. Were it to generate it, what gets
published would not be what is versioned, and the binary's name or the app id could
come out different without anybody noticing.

### What has to be verified about the `.deb`

Compiling is not enough. Every time:

```sh
docker run --rm -v ~/keel-build/out:/out ubuntu:24.04 bash -c '
  apt-get update -qq && apt-get install -y /out/keel_*.deb
  ldd /opt/keel/keel | grep "not found"       # has to come out empty
  ls /opt/keel/lib/liboffline_first_core.so'  # the database has to travel
```

And that `Depends:` states the glibc the binary **actually** asks for:

```sh
objdump -T <binary> | grep -o 'GLIBC_[0-9.]*' | sort -Vu | tail -1
```

Over-declaring is not conservative, it is a package that refuses to install where it
would have worked. Both under-declaring and over-declaring must be avoided; inspect all bundled
libraries, not just the launcher.

## Windows

### Why it cannot be cross-compiled

It is not a limitation that can be configured away. From the SDK itself:

```
build_windows.dart:97   'Unable to find suitable Visual Studio toolchain. '
build_windows.dart:199  '-G', generator,     ← Visual Studio generator
```

Flutter looks for MSVC and aborts. And containers do not help: **Windows containers
need a Windows host**, because they share the kernel with it. Docker on macOS or on
Linux only runs Linux containers. Neither the Mac nor `hp-server` can produce an
`.exe`, with or without Docker.

### The two real routes

**GitHub Actions with a Windows runner** — a real Windows host with Visual Studio,
without buying or configuring hardware. Actions supports Windows builds; this
project's missing database binary is the blocker. See the current
[GitHub-hosted runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).

**A Windows VM on `hp-server`** — also viable: it has `/dev/kvm`, 8 threads with
virtualization, 15 GB of RAM, and 755 GB free. Give a Windows 11 8 GB and 100 GB,
install Visual Studio, and build there. More setup, but it depends on nobody.

Either one works. **Neither works yet**, because the blocker is the database, not
the machine. A CI that fails in CMake is noise, not information.

## The plan for unblocking arm64 and Windows

There are two paths and they are mutually exclusive.

**A. Migrate to sqlite.** `sqlite3` + `sqlite3_flutter_libs` compile the
amalgamation with CMake on every platform, so there are no prebuilt binaries that
can be missing: any architecture, Windows and Linux arm64 included.

The scope is deliberately contained: `local_database.dart` is the only file that
imports `flutter_local_db`, and its static API does not change, so no repository or
ViewModel finds out. `key_index.dart` is deleted entirely — it exists only to paper
over the package having no prefix query — and a one-time data migration is needed.

Three problems that already exist on macOS today go away as a bonus: the whole
database resident in RAM, the `GetAll` that serializes everything over FFI on every
launch, and `replaceAllWithPrefix` without a transaction.

**B. Complete `flutter_local_db`.** The package is ours, so what is missing can be
added: the Rust core compiled for `x86_64-pc-windows-msvc` (possible from Linux
with `cargo-xwin`), a C++ shim with its `CMakeLists` in `windows/`, the `aarch64`
`.so` for Linux ARM, and — while we are at it — a prefix query.

It is more work than A, and afterward a storage engine has to be maintained.

While neither is done: macOS and Linux x86_64 work fine and there is no urgency. The
decision gets taken when Windows stops being hypothetical.

## Secrets and symbols

**`keel_secrets.json` is not in the repo** (it is in `.gitignore`). It carries the
error channel's webhook. Without that file the app still compiles, it simply reports
nothing.

Mind what that does *not* protect: a `--dart-define` ends up as a **plain string**
inside the binary and is extracted with `strings` in five seconds. Obfuscation does
not cover it — it renames symbols, never literals, because touching them would break
every `toString()`. A webhook embedded in a distributed client is public by
definition; the only thing that really fixes it is the secret living on a server.

**There are no symbols to archive** while `--obfuscate` is not used. The stacks
that reach the error channel are read as-is, with nothing to translate.

## An open bug: the sub-windows' icons

In a **release** build, the main window draws all its icons correctly and the
Assistant's sub-window draws **all** of them as the missing-glyph box.

What has already been ruled out:

- **It is not icon tree-shaking.** `MaterialIcons-Regular.otf` weighs exactly
  17,852 bytes both in a normal build and in an obfuscated one: byte for byte the
  same file. The font the working window uses is the same one the failing one uses.
- **It is not obfuscation.** The symptom appears the same without it.

What the pattern does point at: every `desktop_multi_window` sub-window is
**another Flutter engine**, and the problem is that engine resolving the asset
bundle in release — where the assets live inside `App.framework/Resources` — and not
the packaging.

That is the next thread to pull. It is not diagnosed.
