import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:window_manager/window_manager.dart';

import 'package:keel_ui/src/core/services/agent_bridge_channel.dart';
import 'package:keel_ui/src/modules/assistant/model/assistant_window_state.dart';

/// SUB-engine side of the assistant window: a passive replica of the state
/// main pushes. It never runs agents, never opens the database — it applies
/// snapshots and forwards the two session intents whose answer the UI needs
/// synchronously ([newSession]/[selectSession]).
///
/// Instantiated only inside the assistant window's engine (the mixin's
/// static is lazy), where the main window's singletons don't exist.
class AssistantWindowViewModel extends ViewModel<AssistantWindowState> {
  AssistantWindowViewModel() : super(const AssistantWindowState());

  int _lastSeq = 0;
  Future<void>? _connecting;

  @override
  void init() {
    updateSilently(const AssistantWindowState());
    // Async on purpose: every state mutation happens after a platform
    // channel round-trip, i.e. outside any build phase.
    unawaited(connect());
  }

  /// Registers this window's push handler and attaches to main. Reentrant —
  /// concurrent calls share the in-flight attempt.
  Future<void> connect() {
    return _connecting ??= _connect().whenComplete(() => _connecting = null);
  }

  Future<void> _connect() async {
    final controller = await WindowController.fromCurrentEngine();

    // Registered BEFORE attach so the first push can never land unheard.
    // A hot-restart of this engine may find the handler slot already taken
    // by our own previous life — that registration still points at a dead
    // closure, so re-registering must win; tolerate the error if it can't.
    try {
      await controller.setWindowMethodHandler((call) async {
        switch (call.method) {
          case 'assistantState':
            _apply(call.arguments as String);
          case 'assistantFocus':
            unawaited(windowManager.focus());
        }
        return null;
      });
    } catch (error) {
      Log.w('No se pudo registrar el handler de la ventana: $error');
    }

    // Attach with retry: right after a hot-restart of MAIN there is a short
    // window where its bridge handler isn't registered yet.
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final reply = await agentBridgeChannel.invokeMethod<String>(
          'assistant.attach',
          jsonEncode({'windowId': controller.windowId}),
        );
        if (reply != null) {
          _apply(reply);
          return;
        }
      } catch (error) {
        Log.w(
          'attach al puente del asistente falló (intento $attempt): '
          '$error',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  Future<void> newSession() async {
    await _requestState('assistant.newSession', const {});
  }

  Future<void> selectSession(String agentId) async {
    await _requestState('assistant.selectSession', {'agentId': agentId});
  }

  Future<void> _requestState(
    String method,
    Map<String, dynamic> payload,
  ) async {
    try {
      final reply = await agentBridgeChannel.invokeMethod<String>(
        method,
        jsonEncode(payload),
      );
      if (reply != null) _apply(reply);
    } catch (error) {
      Log.w('$method falló: $error');
    }
  }

  /// Applies a snapshot if it's newer than the last one — pushes and RPC
  /// returns race on the channel, and seq (emitted only by main) is the
  /// tiebreak. Snapshots are complete, so dropping a stale one loses nothing.
  void _apply(String json) {
    final state = AssistantWindowState.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
    if (state.seq <= _lastSeq) return;
    _lastSeq = state.seq;
    updateState(state);
  }
}

mixin AssistantWindowClientService {
  static final ReactiveNotifier<AssistantWindowViewModel> instance =
      ReactiveNotifier<AssistantWindowViewModel>(
        () => AssistantWindowViewModel(),
      );
}
