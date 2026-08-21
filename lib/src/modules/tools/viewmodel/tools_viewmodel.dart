import 'dart:async';

import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/tools/model/tool.dart';
import 'package:keel_ui/src/modules/tools/repository/tools_repository.dart';
import 'package:keel_ui/src/shared/shared.dart';

class ToolsViewModel extends ViewModel<ToolsState> {
  ToolsViewModel() : super(const ToolsState());

  ToolsRepository get _repository => ToolsRepository();

  /// Resolves once the persisted catalog has loaded into [data]. Anything
  /// that checks "does this tool exist" outside a widget (e.g. a Keel AI
  /// `create_tool` call landing right after startup) must await this first —
  /// checking against an empty in-flight list would insert a duplicate the
  /// moment the real load lands.
  ///
  /// Memoized rather than a `late final` set once in [init]: a ViewModel
  /// touched before any [BuildContext] exists gets `init()` called a second
  /// time the moment its first context-bearing subscriber mounts —
  /// `reactive_notifier`'s own `reinitializeWithContext()`. A `late final`
  /// assigned again there throws; this getter just returns the
  /// already-in-flight future instead.
  Future<void>? _ready;
  Future<void> get ready => _ready ??= _loadPersistedTools();

  @override
  void init() {
    // Only reset state on the FIRST init — a re-init triggered by the
    // context hand-off above must not wipe a catalog that already loaded.
    if (_ready == null) updateSilently(const ToolsState());
    unawaited(ready);
  }

  Future<void> _loadPersistedTools() async {
    try {
      final tools = await _repository.load();
      updateState(data.copyWith(tools: tools));
    } catch (error) {
      Log.e('Failed to load persisted tools', error: error);
    }
  }

  /// The subset of the catalog whose names appear in [names], in catalog
  /// order. Names that don't resolve are silently skipped — a profile can
  /// reference a tool that was deleted afterwards.
  List<Tool> toolsByNames(List<String> names) =>
      data.tools.where((tool) => names.contains(tool.name)).toList();

  /// Registers a new tool. Returns a user-facing error message on failure
  /// (invalid fields or duplicate name), or null on success.
  String? createTool({
    required String name,
    required String description,
    required ToolRuntime runtime,
    required String code,
    required int timeoutSeconds,
    List<String> secretNames = const [],
  }) {
    final error = _validate(
      name,
      description: description,
      code: code,
      timeoutSeconds: timeoutSeconds,
    );
    if (error != null) return error;

    final tool = Tool(
      id: generateUuidV4(),
      name: name,
      description: description.trim(),
      runtime: runtime,
      code: code.trim(),
      timeoutSeconds: timeoutSeconds,
      secretNames: secretNames,
      createdAt: DateTime.now(),
    );
    final tools = [...data.tools, tool];
    updateState(data.copyWith(tools: tools));
    unawaited(_repository.save(tools));
    return null;
  }

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
  }) {
    final error = _validate(
      name,
      description: description,
      code: code,
      timeoutSeconds: timeoutSeconds,
      excludingId: id,
    );
    if (error != null) return error;

    final tools = data.tools
        .map(
          (tool) => tool.id == id
              ? tool.copyWith(
                  name: name,
                  description: description.trim(),
                  runtime: runtime,
                  code: code.trim(),
                  timeoutSeconds: timeoutSeconds,
                  secretNames: secretNames,
                )
              : tool,
        )
        .toList();
    updateState(data.copyWith(tools: tools));
    unawaited(_repository.save(tools));
    return null;
  }

  void deleteTool(String id) {
    final tools = data.tools.where((tool) => tool.id != id).toList();
    updateState(data.copyWith(tools: tools));
    unawaited(_repository.save(tools));
  }

  String? _validate(
    String name, {
    required String description,
    required String code,
    required int timeoutSeconds,
    String? excludingId,
  }) {
    final formatError = validateToolName(name);
    if (formatError != null) return formatError;

    final isTaken = data.tools.any(
      (tool) => tool.name == name && tool.id != excludingId,
    );
    if (isTaken) return 'Ya existe una tool con ese nombre.';

    if (description.trim().isEmpty) {
      return 'La descripción no puede estar vacía: es lo que le dice al '
          'agente cuándo usar la tool y qué significa cada argumento.';
    }
    if (code.trim().isEmpty) return 'El código no puede estar vacío.';
    if (timeoutSeconds < 1 || timeoutSeconds > kMaxToolTimeoutSeconds) {
      return 'El timeout debe estar entre 1 y $kMaxToolTimeoutSeconds '
          'segundos.';
    }
    return null;
  }
}

mixin ToolsService {
  static final ReactiveNotifier<ToolsViewModel> instance =
      ReactiveNotifier<ToolsViewModel>(() => ToolsViewModel());
}
