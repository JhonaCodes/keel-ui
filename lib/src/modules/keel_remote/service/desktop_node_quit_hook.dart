import 'dart:async';

import 'package:window_manager/window_manager.dart';

import 'package:keel_ui/src/modules/keel_remote/viewmodel/desktop_node_viewmodel.dart';

/// Best-effort stop of this PC's node when keel-ui's main window closes:
/// the link stops polling and reports what it can in three seconds.
///
/// Fire-and-forget on purpose, like `KeelE2eQuitHook`: a window close is not
/// held for it. Nothing depends on it finishing — which task follows what is
/// already in `tasks.json` (saved on every change), so the node resumes
/// reporting where it left off when the app opens again, and keel-api shows
/// it offline once its 30-second status reports stop.
///
/// A no-op when this PC is not a node.
class DesktopNodeQuitHook with WindowListener {
  DesktopNodeQuitHook._();

  static bool _installed = false;

  static void install() {
    if (_installed) return;
    _installed = true;
    windowManager.addListener(DesktopNodeQuitHook._());
  }

  @override
  void onWindowClose() {
    unawaited(DesktopNodeService.instance.notifier.stopOnQuit());
  }
}
