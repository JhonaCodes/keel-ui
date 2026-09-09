# F0 — Multi-window foundation

## What it is

Infrastructure for the app to open additional OS windows (separate Flutter
engines) without duplicating heavy state, and for the main window to PUSH method
calls into a sub-window.

## Problem it corrects

`main()` ran `LocalDatabase.ensureInitialized`, the legacy migration,
`seedKeelAi`, and the startup of BOTH local MCP servers BEFORE the switch on
`businessId`: every sub-window (a separate engine) duplicated the LMDB handle,
the seed, and two HTTP servers backed by empty ViewModels.

## Changes

- `lib/main.dart` — the heavy init lives INSIDE the `idMain` case. Sub-windows
  initialize only bindings plus window_manager.
- `lib/src/core/services/app_window_service.dart`:
  - `openAppWindow` now RETURNS the `WindowController` and registers it by
    `businessId` (it used to discard it — and that was the only vehicle for a
    main→sub push).
  - `openOrFocusAppWindow(args)` — guarantees a single live window per
    `businessId` (`show()` if one already exists).
  - `liveWindowController(businessId)` — validates against
    `WindowController.getAll()` (0.3.0 has no close callback) and RE-ADOPTS live
    windows after a hot restart of main by scanning their launch arguments.
  - `invokeOnWindow(businessId, method, args)` — a push tolerant of a dead
    window: it cleans the registry and returns false, never throws.

## Known limits

- The per-window channel is FIFO but with no delivery guarantee: whoever pushes
  must treat `false` as "nobody is listening", not as an error.
