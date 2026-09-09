# Knowledge base: LLM provider architecture

This base covers **a single domain**: how Keel UI invokes third-party CLIs
(`claude`, `codex`, and whichever get added) and providers' direct HTTP APIs.
`lib/src/integrations/` has ~40 subsystems — the vast majority (boards_mcp,
catalog_bundle, system_vault, git_worktree, fault_journal, mcp_catalog,
roadmap_mcp, requirements_mcp, app_update, genui, jobs_api, and so on) are **not
part of this domain**: they are integrations of other app features and are ignored
for this work.

## Where to look

| Folder | Role | Relevance |
|---|---|---|
| `llm/` | **The domain's implementation.** The `LlmProvider` sealed class (`src/llm_provider.dart`), the dispatcher (`src/llm_dispatcher.dart`, no `default:` and no `_ =>` catch-all — a new provider without its branch must not compile), and one subfolder per provider: `claude/`, `codex/`, `openai_compatible/`. `LlmProvider.fromLegacyAlias` is the single point that maps the persisted alias to the sealed class. | Read first |
| `task_runner/` | **The isolate boundary.** `task_runner_isolate.dart` runs the turn; `task_run_spec.dart` defines the `TaskRunSpec` that crosses the boundary (`fromMessage`/`toMessage`) — primitives only, never an object with semantics; `task_event.dart` defines the events that come out of the CLI process. | Read in full before touching any runner |
| `task_runner/task_runner.dart` | The module's barrel — the `part of` connecting `task_runner_isolate.dart` with the rest | Entry point for locating the module's other files |
| `hook_delivery/` | How the hooks/settings handed to Claude (`--settings`) and Codex (`-c hooks.*` overrides, see `codex_config_overrides.dart`) are resolved and rendered | Consult only if a new runner needs to understand how that temporary file is assembled — not the central focus |
| `machine/src/service_probe.dart` | Detects whether a CLI is installed and at what version — it has the same "find the binary on PATH" logic a new runner needs | Useful reference for CLI flag verification and for any installed-CLI detection |

## Invariants that hold here

1. The sealed class never crosses the `SendPort` as-is: it is built **inside** the
   turn's isolate from primitive fields that do travel.
2. The `llm_dispatcher.dart` switch admits no `default:` and no `_ =>`. The
   `llm-provider-invariants-guard` hook enforces it mechanically.
3. Secrets always by `secretRef` — never in argv (`ps` reads it), never
   interpolated into a header built as a string, never in logs.
4. The output contract is a normalized `Stream<LlmEvent>`, with no exceptions. Each
   runner translates its native format before the event leaves the runner.
5. Persistence backward compatibility: agents already stored on disk carry
   `provider: 'codex'` / `'claude'` as a plain string. The string→sealed mapping
   lives in one place, with an explicit regression test for both legacy values.
6. Each provider folder brings its own transport sealed (`Cli | Api`). A provider
   with only one implemented has only one branch — never a placeholder branch that
   silently throws `UnimplementedError`.

## What is NOT here

Everything else in `lib/src/integrations/` (catalog persistence, Keel's own MCPs
such as `assistant_mcp`/`boards_mcp`/`roadmap_mcp`, the system backup, git
worktrees, app updates) belongs to other domains of the app and is not touched as
part of this LLM provider work.
