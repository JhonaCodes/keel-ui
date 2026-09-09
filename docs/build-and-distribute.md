# Building and distributing Keel

This is not a feature: it is how what people download gets produced. It is here
because the three platforms have different constraints and none of them is
obvious, and because half the decisions below were taken after something failed.

## Where we stand

| Platform | State | Where it builds |
|---|---|---|
| macOS (arm64 + x86_64) | ✅ works | the Mac, natively |
| Linux x86_64 | ✅ works | `hp-server`, in a container |
| Linux arm64 | ❌ impossible today | — |
| Windows x64 | ❌ does not compile | — |

Both ❌ have the **same** cause, and it is not the lack of a machine.

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

1.5.1 is the latest published version; there is no update that resolves it.

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

### Why in a container and not on the host

`hp-server` runs Ubuntu 24.04 with **glibc 2.39**. A binary compiled there requires
glibc ≥ 2.39, and that leaves out Ubuntu 22.04, Debian 12, and Mint — meaning most
real machines. Building inside an Ubuntu 22.04 container, the binary asks for
**glibc 2.34**, which covers Ubuntu 21.10 and RHEL 9 onward.

It is still natively x86_64: the container emulates nothing, it only fixes which
libraries it links against.

### How it is done

The image (`ubuntu:22.04` + Flutter's toolchain + `libgtk-3-dev`) is built once and
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
docker run --rm -v ~/keel-build/out:/out ubuntu:22.04 bash -c '
  apt-get update -qq && apt-get install -y /out/keel_*.deb
  ldd /opt/keel/keel | grep "not found"       # has to come out empty
  ls /opt/keel/lib/liboffline_first_core.so'  # the database has to travel
```

And that `Depends:` states the glibc the binary **actually** asks for:

```sh
objdump -T <binary> | grep -o 'GLIBC_[0-9.]*' | sort -Vu | tail -1
```

Over-declaring is not conservative, it is a package that refuses to install where it
would have worked. It happened to us: it said 2.35 when it asked for 2.34.

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

**GitHub Actions with `windows-latest`** — the recommended one. A real Windows
runner with Visual Studio 2022 preinstalled, without buying or configuring
hardware. A build takes ~10 min and the free plan gives 2000 min/month on private
repos. The `.exe` comes out as an artifact.

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
