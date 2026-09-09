# F22 — Hooks: guardrails that run on their own

## Problem it solves

keel-ui administered skills, rules, tools, workflows, MCPs, agents, projects, and
knowledge bases. Of hooks, nothing: `grep -i hook` over `lib/` returned not a
single result.

What existed was written by hand in `~/.claude/settings.json` and applied to
**every** subprocess this app launches, without the app knowing or showing it —
`--strict-mcp-config` isolates MCPs, not hooks. Then a cleanup carried them off
and the scripts they referenced disappeared. In other words: invisible when they
worked, and silently dead afterward.

## A hook is NOT a rule

This is the confusion to avoid, because it leads to writing a rule and expecting
it to enforce itself.

| | Rule | Hook |
|---|---|---|
| What it is | Prose in the system prompt | A command on a CLI event |
| Who decides | The model | The process, before the model |
| Can it be ignored? | Yes | No |
| Does it block? | No | Yes (`exit 2`) |
| Does it react? | No | Yes (format after an Edit) |
| When it fails | Silently | With a message and a code |

*"Don't commit without running the tests"*: as a rule, the agent almost always
obeys and when it does not, you find out later; as a hook, the commit **does not
happen**.

They are kept separate but linked: a hook declares in `enforces` which rules it
enforces, and the Rules screen shows which are **guaranteed** and which depend on
the model obeying.

## How it reaches the CLI

Both CLIs have native hooks and — verified on the machine, not assumed — the
**same** configuration shape: event → matcher → commands, `exit 2` blocks,
`hookSpecificOutput.permissionDecision` denies. And codex's 11 events are an
**exact subset** of claude's ~30.

So nothing is intercepted: a hook is defined once and materialized when the turn
is launched.

- **claude** → a `settings.json` with `--settings <path>`. It adds to whatever the
  user has in their config; keel-ui administers its own and does not adopt others'.
- **codex** → a TOML profile in `$CODEX_HOME` with `-p <profile>`. It layers over
  the user's config, applies to that invocation, and is deleted.

`CliTurnWorkspace` (`lib/src/core/services/cli_turn_workspace.dart`) unifies the
turn's 0700 temporary directory, which used to be duplicated between
`ClaudeCliService` and the task runner's isolate. In there go the `mcp.json` that
already existed, the hooks config, and one wrapper per hook.

### Why there is a wrapper

1. **Secrets.** The CLI inherits the app's environment, so putting a secret there
   would hand it to everything else. The wrapper exports **only** the ones that
   hook declares.
2. **Tools as a body.** It materializes the tool's code and runs it with its
   runtime.
3. **It marks the block.** When the hook exits with 2, it appends
   `[keel:hook <name>]` to stderr.

The body **always** goes to a separate file, even a one-line command: were it
inline, its `exit 2` would end the wrapper before it could leave the mark. (And a
bash tool produced a file with the same name as its wrapper — the wrapper called
itself in infinite recursion. Hence `<hook>.body.<ext>`.)

## Blocking is not a missing permission

keel-ui never answers a permission request: the CLI runs headless, denies, and the
app **observes** `system/permission_denied`. When the user granted it, a global
setting was switched on and a new turn was sent. That reflex would be wrong for a
hook: no permission unblocks that.

Testing against the real CLI surfaced something unplanned: **a hook that blocks
does NOT arrive as `permission_denied`**, it arrives as the error result of the
tool it stopped — a `user` event keel-ui did not parse at all. Without that, the
block would only have been reported by the model in prose.

Now both parsers (the service's and the isolate's) recognize that result **by the
wrapper's mark**, so it only fires with keel-ui hooks: one the user has in their
own config does not carry it, and neither does an ordinary tool error. The banner
says which hook it was and where to go, with no grant button.

## Where it is assigned

Globally, per agent (`AgentProfile.hooks`), and per project
(`Station.hookNames`), just like rules.

**Keel AI is always exempt.** That is not convenience: it is the emergency exit. A
badly written hook can jam every agent, and the way to fix it is to turn it off —
if the thing that can turn it off were jammed too, there would be no way out. So
Keel AI runs unrestricted and has `set_hook_enabled` and `delete_hook`.

## Deleting means deleting everywhere

Here the module deliberately departs from how a rule is deleted, which leaves the
name dangling in profiles and projects. `deleteHook` **cascades**, and renaming
drags the assignments along. A dead reference to a guardrail lies about what is
protected. The dialog says what it will release before doing it.

## Importing what you already had

`Hooks → Import from Claude Code` reads `~/.claude/settings.json` and its backups,
deduplicates by event + matcher + command, and brings the entities in **disabled**,
flagging which ones point at files that no longer exist.

## Verification

1. A `PreToolUse`/`Bash` hook that denies `rm -rf`: the command does not run and
   the UI says which hook stopped it, without offering "grant permission".
2. The same hook in a **project** — proving the isolate's path is covered.
3. The same hook with a **codex** agent.
4. A "claude only" hook with a codex agent: the form flags it and the turn reports
   that it was not applied.
5. A hook with a tool body and a declared secret: it runs with the secret in its
   environment, and that secret does not appear in the CLI's.
6. A disabled hook is not written into the generated config.
7. **The emergency exit**: a global hook that denies everything. The agents are
   jammed; Keel AI carries on and turns it off.
8. **Cascade**: assign it to 2 agents and 1 project, delete it, and verify the
   name is left in no list.
9. Back up the vault: `catalog/hooks/*.json`; restoring clean returns them.

### What has already been verified against the real CLIs

- **claude**: with a `settings.json` generated by this feature, a
  `PreToolUse`/`Bash` hook blocked the command, the CLI executed nothing, and the
  `[keel:hook <name>]` mark arrived in the result.
- **codex**: the `-p` profile loaded **with no trust prompt at all**, which was the
  open risk. The hook never got to fire because the account ran out of credits, so
  that half remains unverified live.
