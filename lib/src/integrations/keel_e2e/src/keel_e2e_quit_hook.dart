part of '../keel_e2e.dart';

/// Best-effort `detach()` of the keel-e2e engine when keel-ui's main window
/// closes. Fire-and-forget on purpose: `KeelE2eHostViewModel.detach()`
/// closes the engine's stdin and waits up to 5 s for its exit, which is
/// longer than this app should block a window close for. The engine's own
/// orphan safety (architecture §5: stdin EOF means the parent is gone) is
/// the real guarantee — this hook only asks for a cleaner, faster shutdown
/// when there IS time for it.
///
/// A no-op if keel-e2e was never attached (`detach()` returns immediately
/// when there is no live process).
class KeelE2eQuitHook with WindowListener {
  KeelE2eQuitHook._();

  static bool _installed = false;

  static void install() {
    if (_installed) return;
    _installed = true;
    windowManager.addListener(KeelE2eQuitHook._());
  }

  @override
  void onWindowClose() {
    unawaited(KeelE2eHostService.instance.notifier.detach());
  }
}
