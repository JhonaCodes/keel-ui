import 'package:keel_core/modules/tools/model/tool.dart';
import 'package:keel_core/modules/tools/service/tools_store.dart';
import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:keel_ui/src/core/services/store_mirror_view_model.dart';

/// Mirror delgado de [ToolsStore] (keel_core): toda la lógica real vive ahí.
class ToolsViewModel extends StoreMirrorViewModel<ToolsState> {
  ToolsViewModel() : super(ToolsStore.instance);

  /// Resolves once the persisted catalog has loaded into [data]. Anything
  /// that checks "does this tool exist" outside a widget (e.g. a Keel AI
  /// `create_tool` call landing right after startup) must await this first —
  /// checking against an empty in-flight list would insert a duplicate the
  /// moment the real load lands.
  Future<void> get ready => ToolsStore.instance.ready;

  /// The subset of the catalog whose names appear in [names], in catalog
  /// order. Names that don't resolve are silently skipped — a profile can
  /// reference a tool that was deleted afterwards.
  List<Tool> toolsByNames(List<String> names) =>
      ToolsStore.instance.toolsByNames(names);

  /// Registers a new tool. Returns a user-facing error message on failure
  /// (invalid fields or duplicate name), or null on success.
  String? createTool({
    required String name,
    required String description,
    required ToolRuntime runtime,
    required String code,
    required int timeoutSeconds,
    List<String> secretNames = const [],
  }) => ToolsStore.instance.createTool(
    name: name,
    description: description,
    runtime: runtime,
    code: code,
    timeoutSeconds: timeoutSeconds,
    secretNames: secretNames,
  );

  /// Updates an existing tool. Returns a user-facing error message on
  /// failure (invalid fields or duplicate name), or null on success.
  String? updateTool(
    String id, {
    required String name,
    required String description,
    required ToolRuntime runtime,
    required String code,
    required int timeoutSeconds,
    List<String>? secretNames,
  }) => ToolsStore.instance.updateTool(
    id,
    name: name,
    description: description,
    runtime: runtime,
    code: code,
    timeoutSeconds: timeoutSeconds,
    secretNames: secretNames,
  );

  void deleteTool(String id) => ToolsStore.instance.deleteTool(id);
}

mixin ToolsService {
  static final ReactiveNotifier<ToolsViewModel> instance =
      ReactiveNotifier<ToolsViewModel>(() => ToolsViewModel());
}
