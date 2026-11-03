part of '../gpt_mcp_node.dart';

/// GPT MCP of the server (keel-server), managed from this PC through
/// keel-api: every action is one `gpt.*` task, and the server's answer is
/// the state shown.
class GptMcpServerViewModel extends ViewModel<GptMcpNodeState>
    implements GptMcpNodeActions {
  GptMcpServerViewModel() : super(const GptMcpNodeState());

  GptMcpServerRepository get _repository => const GptMcpServerRepository();

  String? _nodeId;

  @override
  void init() {
    unawaited(refresh());
  }

  /// Runs [type] on the server and hands its result to [apply]; a failure
  /// becomes the section's error line.
  Future<void> _run(
    String type,
    Map<String, Object?> payload,
    GptMcpNodeState Function(Map<String, dynamic> result) apply,
  ) async {
    updateState(data.copyWith(busy: true));
    var nodeId = _nodeId;
    if (nodeId == null) {
      final found = await _repository.serverNodeId();
      nodeId = found.when(
        ok: (id) => id,
        err: (message) {
          updateState(data.copyWith(busy: false, error: message));
          return null;
        },
      );
      if (nodeId == null) return;
      _nodeId = nodeId;
    }
    final result = await _repository.run(nodeId, type, payload);
    result.when(
      ok: (value) =>
          updateState(apply(value).copyWith(busy: false, clearError: true)),
      err: (message) {
        // The server may have re-enrolled: look it up again next time.
        _nodeId = null;
        updateState(data.copyWith(busy: false, error: message));
      },
    );
  }

  @override
  Future<void> refresh() async {
    _nodeId = null;
    await _run('gpt.status', const {}, data.withReport);
    await browse(data.browsePath.isEmpty ? null : data.browsePath);
  }

  @override
  Future<void> browse(String? folder) => _run(
    'gpt.tree',
    {'path': ?folder},
    (tree) => data.copyWith(
      browsePath: tree['path'] as String?,
      folders: [
        for (final folder in tree['folders'] as List<dynamic>? ?? const [])
          GptFolderNode.fromJson(folder as Map<String, dynamic>),
      ],
    ),
  );

  @override
  Future<void> setEnabled(bool enabled) =>
      _run('gpt.toggle', {'enabled': enabled}, data.withReport);

  @override
  Future<void> setGrant(String folder, GptAccessMode? mode) async {
    await _run('gpt.grant', {
      'path': folder,
      'mode': mode?.name ?? 'none',
    }, data.withReport);
    await browse(data.browsePath);
  }

  @override
  Future<void> decide(String requestId, GptAccessDecision decision) => _run(
    'gpt.decide',
    {'id': requestId, 'decision': decision.name},
    data.withReport,
  );

  @override
  Future<void> createFolder(String folder, GptAccessMode mode) async {
    await _run('gpt.mkdir', {
      'path': data.folderPath(folder),
      'mode': mode.name,
    }, data.withReport);
    await browse(data.browsePath);
  }
}

mixin GptMcpServerService {
  static final ReactiveNotifier<GptMcpServerViewModel> instance =
      ReactiveNotifier<GptMcpServerViewModel>(() => GptMcpServerViewModel());
}
