import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_core/modules/hooks/model/hook.dart';
import 'package:keel_core/modules/hooks/model/hook_event.dart';
import 'package:keel_core/modules/hooks/service/hooks_store.dart';
import 'package:keel_ui/src/core/services/store_mirror_view_model.dart';

export 'package:keel_core/modules/hooks/model/hook.dart' show HooksState;

/// Thin mirror over [HooksStore] (keel_core): the real catalog, validation
/// and cross-reference logic lives there so keel-server can run
/// it without Flutter.
class HooksViewModel extends StoreMirrorViewModel<HooksState> {
  HooksViewModel() : super(HooksStore.instance);

  Future<void> get ready => HooksStore.instance.ready;

  List<Hook> hooksByNames(Iterable<String> names) =>
      HooksStore.instance.hooksByNames(names);

  Hook? hookByName(String name) => HooksStore.instance.hookByName(name);

  List<Hook> get globalHooks => HooksStore.instance.globalHooks;

  String? createHook({
    required String name,
    required String description,
    required HookEvent event,
    required HookBody body,
    String matcher = '',
    int timeoutSeconds = kDefaultHookTimeoutSeconds,
    List<String> enforces = const [],
    bool isGlobal = false,
    bool enabled = true,
  }) => HooksStore.instance.createHook(
    name: name,
    description: description,
    event: event,
    body: body,
    matcher: matcher,
    timeoutSeconds: timeoutSeconds,
    enforces: enforces,
    isGlobal: isGlobal,
    enabled: enabled,
  );

  String? updateHook(
    String id, {
    required String name,
    required String description,
    required HookEvent event,
    required HookBody body,
    String matcher = '',
    int timeoutSeconds = kDefaultHookTimeoutSeconds,
    List<String>? enforces,
    bool? isGlobal,
    bool? enabled,
  }) => HooksStore.instance.updateHook(
    id,
    name: name,
    description: description,
    event: event,
    body: body,
    matcher: matcher,
    timeoutSeconds: timeoutSeconds,
    enforces: enforces,
    isGlobal: isGlobal,
    enabled: enabled,
  );

  String? setEnabled(String id, bool enabled) =>
      HooksStore.instance.setEnabled(id, enabled);

  ({int profiles, int projects}) assignmentsOf(String hookName) =>
      HooksStore.instance.assignmentsOf(hookName);

  void deleteHook(String id) => HooksStore.instance.deleteHook(id);
}

mixin HooksService {
  static final ReactiveNotifier<HooksViewModel> instance =
      ReactiveNotifier<HooksViewModel>(() => HooksViewModel());
}
