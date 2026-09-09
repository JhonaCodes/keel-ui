# F1 — The assistant's window (Keel AI)

## What it is

The chat with Keel AI lives in a dedicated OS WINDOW (replacing the side panel,
which was removed). While you talk in there, the main app changes live: the
`keelai-actions` MCP mutates the main engine's ViewModels, and its screens are
already reactive to those ViewModels.

## Architecture — a dumb presentation client

The window runs ANOTHER Flutter engine whose singletons are empty. It has no
`AgentsViewModel`, does not open LocalDatabase, does not start MCPs. It renders
snapshots main pushes to it and returns intentions over a method channel.

### Protocol

- **sub→main** (the existing `keel_ui/agent_bridge` channel, handler in main):
  methods prefixed `assistant.` — `attach`, `sendMessage`, `stop`,
  `deleteMessage` (timestamp in µs epoch), `setModel`, `setEffort`,
  `requestCompact`, `respondPermission`, `setFullFileSystemAccess`,
  `deleteAgent`, `newSession`, `selectSession`. Payload = a JSON String. The
  methods that change the session RETURN the new state.
- **main→sub**: the registered `WindowController` (F0) plus `invokeMethod` with
  `assistantState` (a snapshot) and `assistantFocus`. The sub registers its
  handler with `WindowController.fromCurrentEngine()` BEFORE calling `attach`.

### Wire state

`AssistantWindowState{seq, activeAgentId, agent, sessions}` with
`AssistantAgentSnapshot` (its own wire model, NOT `Agent.toJson`, which is
persistence): it includes transients (isStreaming, liveReasoning,
currentActivity, pendingPermission). **fileEdits are omitted** (the only
unbounded source; keelai acts through MCP, not through edits) and beyond ~1MB the
oldest messages are trimmed (on the wire only; the real thread stays intact).

`seq` is monotonic and only main emits it; the sub discards `seq <=` the last one
applied — pushes and RPC returns can race without corrupting anything, because
every snapshot is complete and idempotent.

### Pieces

- `assistant/service/assistant_window_bridge.dart` — the MAIN side (a flat
  singleton, not RN: nothing in this engine renders it). A listener over
  `AgentsService` filtered by keelai sessions, deep comparison to avoid pushing
  without changes, a 30ms debounce, and automatic detach when a push finds no
  window.
- `assistant/viewmodel/assistant_window_viewmodel.dart` — the SUB side: a
  passive `ViewModel<AssistantWindowState>` replica; `connect()` with
  retry/backoff (a hot restart of main leaves a window with no handler); applies
  pushes and returns with a seq guard.
- `agents/service/chat_actions.dart` — the `ChatActions` port with
  `LocalChatActions` (the default: this engine's singleton; existing callers do
  not change) and `assistant/service/bridge_chat_actions.dart` (RPC).
  `ChatView` and `ChatMessageBubble` no longer touch the singleton directly.
- `assistant/ui/screen/assistant_window.dart` — its own MaterialApp with
  `buildAppTheme()`, a sessions menu plus new conversation, and the SAME
  `ChatView` with `actions: BridgeChatActions()`.
- `PermissionRequest` and `AgentToolActivity` gained toJson/fromJson (wire).

## The assistant does NOT appear in the agent lists

Its sessions are filtered out of the two surfaces that list agents: the rail (by
`keelAiProfileId`) and the "Loose agents" section of the projects sidebar (by
`AgentsViewModel.listableAgents`, which keeps the rule in a single place). Keel AI
lives in its window and nowhere else — mixing its sessions with the agents the
user registered is exactly the confusion that window exists to prevent.

It also cannot end up selected in the conversation area: `createAgentSilently`
does not touch `selectedAgentId`, so a keelai session never becomes the main
window's active agent.

## Flows

- **Open**: ✨ on the rail → `AssistantWindowBridge.instance.open()` (resolves
  the keelai session in the tap handler — never in build), opens or focuses the
  single window, and pushes `assistantFocus`.
- **Permissions**: the banner travels in the snapshot; `respondPermission` runs
  the real logic in main (including the automatic continuation).
- **Delete session**: main deletes and resolves or creates the next one — the
  window is never left showing a phantom agent.

## Known limits

- fileEdits are not rendered in this window (by design).
- Closing the main app closes the whole process (sub-windows die with it).
- One assistant window at a time (registry by businessId).

## The window opened black, and why

The first time it opened in a run, a black rectangle appeared; the second time,
not. The cause was **two `show()` calls racing**.

Sub-windows are born hidden so `_showWhenPainted` can show them after the first
frame. But the window also did its own `windowManager.show()` from `initState`,
when no frame exists yet. And `waitUntilReadyToShow` resizes and centers **after**
showing, so the new area was left unpainted.

The second time it did not happen because the process is already warm — snapshot,
fonts, pipelines — and the first raster arrives before the race. Hence closing and
reopening seemed to fix it.

Now `initState` configures and nothing else, and the only thing that shows is
`_showWhenPainted`, which also takes focus. On top of that, all three windows
declare a `backgroundColor`: any gap before the first raster is the empty
`FlutterView`, which reads as black, and with a background set it is the app's
color. The main window's gap is unavoidable — it is shown before `runApp` — but
what color it is can be chosen.
