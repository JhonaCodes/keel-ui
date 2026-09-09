# F36 — Knowing which Keel you are running, and downloading the new one

## Problem it solves

Keel may be installed from a `.dmg` or run from its own source with
`flutter run -d macos`. They are two different cases and the UI does not mix
them:

- below **Settings** the open bundle's version always appears;
- if `https://jhonacode.com/keel/latest.json` publishes a later one, that same
  version lights up with a download icon and opens exclusively the URL declared
  by the official channel;
- **Machine** keeps the checkout's diagnosis for whoever develops: remote commits
  and local code not yet rebuilt.

If the manifest does not answer, the installed version stays visible and no false
notice appears. The query happens at launch, without blocking the app, and honors
the same six-hour TTL as the repository check.

For a copy run from the repo there are still three questions, and the third is the
one that bites:

| Question | Where the answer comes from |
|---|---|
| What code do I have? | `git log -1` in the repo the app was launched from |
| Is there anything new? | `git fetch` plus the missing commits |
| Am I running what I have? | the binary's date against the commit's |

Nobody asks the third one, and it explains the "but I already fixed that".
Fetching commits **does not change what is running**: the binary you have open is
from the last time you built. This screen says so instead of letting you believe
you already moved to the new version.

## Finding the source

There is no path to configure. It walks up from the executable until it finds a
folder that has Keel's `pubspec.yaml` **and** a `.git`:

```
…/build/macos/Build/Products/Debug/Keel.app/Contents/MacOS/Keel
                                                     ↑ eight folders up
/repos/keel-ui        ← pubspec.yaml with `name: keel_ui` + .git
```

Both conditions matter: somebody else's checkout `build/` could have the first,
and every repo in the world has the second. If you copied the `.app` to
`/Applications` without the source next to it, nothing is found, and that is
exactly what the screen says — instead of inventing a path.

## The version below Settings

The rail shows `vMAJOR.MINOR.PATCH` below the Settings button. The tooltip
includes the build. When there is a later release, the text takes the primary
color, the download icon appears, and a click opens the published DMG. When it is
up to date, a click forces a manual check.

The installed version is read from the bundle with `package_info_plus`; it is not
duplicated as a UI string. The comparison covers semver and build.

## The development section in Machine

It goes at the very top of **Machine**, with that screen's other three questions:
which CLIs are installed, how much was spent, how the hardware is doing. Things
about this machine, not about the work.

```
KEEL ─────────────────────────────────────────────────────────── main

  5189713   fix: a consultation's box measures what it says
  code from 2 h ago  ·  built 5 h ago
  /repos/keel-ui

There are 3 new commits on `main`.
  a1b2c3d  feat: the failure log
  …

                                    [Check]  [Fetch 3 commits]
```

The date line turns red when the binary is older than the commit: you are running
code that is no longer what you have on disk.

## What prevents it

The reasons are data and not exceptions, just like unifying a worktree: an
operation that touches the repo the app runs from is examined whole before
starting.

- **There is no repo alongside** → there is nothing to fetch.
- **Uncommitted changes** → a `pull` on top of that refuses, and rightly so.
- **The branch tracks nothing on the remote** → there is nothing to compare
  against.

Running sessions do **not** stop the `pull`: Keel's repo is not your projects'
repo. They do stop the rebuild, which closes the app with turns half-done.

## One step, and the rest in the Terminal

Updating does exactly one thing: `git pull --ff-only`.

Building needs the `flutter` from **your** PATH, and a macOS app starts with a
minimal one — `/usr/bin:/bin:/usr/sbin:/sbin` — where `git` is present and
`flutter` is not. Trying anyway would be a "command not found" dressed up as a
Keel bug.

That is why "Rebuild and reopen" opens the Terminal, which does bring up your real
shell:

```
cd '/repos/keel-ui' && flutter run -d macos
```

…and closes Keel. Closing is part of the job and not a side effect: the binary you
are running is the one `flutter run` is about to replace, and two Keels over the
same LMDB database is exactly the problem the app avoids everywhere else. The exit
is the orderly one — the same as Cmd+Q — so the closing backup gets a chance to
run.

## When it checks

Once at launch, quietly and without blocking, and then every six hours at most. A
project that moves every day does not publish commits every half hour, and every
check is a real `git fetch`. The **Check** button ignores that deadline, which is
what it exists for.

When there are new commits or a binary older than the code, a dot lights up in
**Machine**. When there is a new DMG, the version below **Settings** lights up.
Each notice lives where its correct action also is.

## Where it lives

| What | Where |
|---|---|
| Finding the repo | `integrations/app_update/src/keel_source.dart` |
| Version and installable manifest | `integrations/app_update/src/release_channel.dart` |
| Semver and manifest validation | `integrations/app_update/release_version.dart` |
| Reading the state and the commits | `integrations/app_update/src/update_probe.dart` |
| What prevents it | `integrations/app_update/src/update_plan.dart` |
| The pull and the relaunch | `integrations/app_update/src/update_run.dart` |
| The screen's section | `integrations/app_update/src/ui/keel_version_section.dart` |
| Building, signing, and producing the manifest | `scripts/build_macos_release.sh` |
