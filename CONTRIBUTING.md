# Contributing to Keel

Contributions are welcome — bug reports, fixes, docs, and new provider
support especially.

Keel is a personal project that is used every day, so the bar is less
"enterprise process" and more "does it hold up and can someone else read it".

## Before you start

For anything larger than a small fix, **open an issue first**. Keel has strong
opinions about its architecture, and a PR that fights them is painful for both
sides. An issue costs five minutes and saves an afternoon.

The roadmap lives in the repo, under [`TASKS/`](TASKS/README.md), and the
reasoning behind each of the 51 features is written down in
[`docs/`](docs/README.md). Reading the doc for the area you want to touch is
usually faster than reading the code.

## Setting up

You need Flutter and, to actually run an agent, at least one of the supported
CLIs (`claude` or `codex`) on your PATH.

```bash
flutter pub get
flutter test          # the suite must be green before you open a PR
flutter analyze       # and this must be clean
flutter run -d macos  # or -d linux
```

The database is local (LMDB) and lives in the app support directory. Nothing
is uploaded anywhere — there is no Keel backend.

## The rules that are not negotiable

These are the ones a review will always check:

- **Widgets are classes**, never functions returning a `Widget`.
- **No business logic in `build()`** — it lives in the ViewModel.
- **ViewModels take no constructor parameters.** Collaborators are resolved
  inside, via service mixins. This is what makes them singletons that outlive
  the UI.
- **One state paradigm per component.** The app is `reactive_notifier`; do not
  introduce Riverpod, BLoC, Provider, or GetX.
- **Errors are values.** `Result<T, E>` from `result_controller`, not
  exceptions for control flow.
- **Models are complete**: `const` constructor, `copyWith`, `==`, `hashCode`,
  `toJson`, `fromJson`.
- **Device class comes from `context.deviceType`**, derived from the window's
  shortest side — never a raw `MediaQuery` width check.

If you find existing code that breaks one of these, it is a bug, not a
precedent.

## Adding an LLM provider

This is the most likely place someone wants to extend Keel, so it has its own
contract:

- The provider sealed class is matched with **no `default:` and no `_ =>`
  catch-all**. A new provider without its branch must fail to *compile*, not
  fall back silently at runtime.
- **Secrets travel as a reference, never in the clear** — not in process argv
  (readable with `ps`), not interpolated into a header ahead of time, not in
  logs. They resolve to a `0700` temp file or a header built at request time.
- Every runner normalizes its native format to `Stream<LlmEvent>` **before the
  event leaves the runner**. Nothing outside the integration layer may depend
  on one provider's response shape.

## Pull requests

- Branch from an up-to-date `main`.
- **Write in English** — code, comments, commit messages, PR title and body.
- One logical change per PR. If the description needs the word "also", it is
  probably two PRs.
- Say how you tested it. "Ran the app and clicked around" is a valid answer;
  saying nothing is not.
- New behavior comes with a test that fails without the change.

## Reporting a bug

Include your OS, the output of `flutter --version`, which CLI and provider you
were using, and what you expected instead. A screenshot of the Map for the
session that went wrong is worth a lot.

## License

By contributing, you agree that your contributions are licensed under the
[MIT License](LICENSE) that covers the project.
