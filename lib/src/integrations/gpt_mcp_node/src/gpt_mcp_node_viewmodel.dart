part of '../gpt_mcp_node.dart';

class GptMcpNodeViewModel extends ViewModel<GptMcpNodeState> {
  GptMcpNodeViewModel() : super(const GptMcpNodeState());

  /// The secret that holds this PC's relay token (keel-api
  /// `KEEL_GPT_MCP_RELAY_TOKEN_PC`). Read at every poll, never shown.
  static const tokenSecret = 'GPT_MCP_RELAY_TOKEN_PC';

  /// Grantable folders live under the data volume when it exists.
  static const _preferredBase = '/Volumes/Data';
  static const _refreshEvery = Duration(seconds: 3);

  Timer? _ticker;

  @override
  void init() {
    // Nothing until main() calls [start]; a second init from mounting
    // Settings must not reset a running node.
  }

  /// Starts GPT MCP as node `pc`. Main window only, after `KeelCoreRuntime.start`.
  Future<void> start() async {
    final base = Directory(_preferredBase).existsSync()
        ? _preferredBase
        : (Platform.environment['HOME'] ?? '/');
    try {
      await GptMcpNode.instance.start(
        GptMcpConfig(
          node: GptMcpNodeKind.pc,
          baseDir: base,
          apiOrigin: KeelAccountState.defaultOrigin,
          relayToken: () => SecretsStore.instance.resolveValue(tokenSecret),
        ),
      );
    } on Object catch (error) {
      Log.w('GPT MCP could not start on this PC: $error');
      updateState(data.copyWith(error: '$error'));
      return;
    }
    await SecretsStore.instance.ready;
    if (SecretsStore.instance.missingOf([tokenSecret]).isNotEmpty) {
      // Shows up as a pending secret: the owner pastes the token there.
      SecretsStore.instance.requestSecret(
        name: tokenSecret,
        why:
            'GPT MCP: relay token of this PC (KEEL_GPT_MCP_RELAY_TOKEN_PC in keel-api)',
      );
    }
    await refresh();
    _ticker?.cancel();
    _ticker = Timer.periodic(_refreshEvery, (_) => unawaited(refresh()));
  }

  /// Re-reads the node's status, grants and requests; only a real change
  /// rebuilds the section.
  Future<void> refresh() async {
    final node = GptMcpNode.instance;
    if (!node.isStarted) return;
    final token = await SecretsStore.instance.resolveValue(tokenSecret);
    final next = data.copyWith(
      status: node.status(),
      grants: await node.access.grants(),
      requests: await node.access.requests(),
      tokenMissing: token == null || token.trim().isEmpty,
    );
    if (next != data) updateState(next);
  }

  Future<void> setEnabled(bool enabled) async {
    if (!GptMcpNode.instance.isStarted) return;
    await GptMcpNode.instance.setEnabled(enabled);
    await refresh();
  }

  /// Grants [folder] with [mode], or removes its grant when [mode] is null.
  Future<void> setGrant(String folder, GptAccessMode? mode) async {
    if (!GptMcpNode.instance.isStarted) return;
    final result = await GptMcpNode.instance.access.setGrant(folder, mode);
    result.when(
      ok: (_) => updateState(data.copyWith(clearError: true)),
      err: (failure) => updateState(data.copyWith(error: failure.message)),
    );
    await refresh();
  }

  Future<void> decide(String requestId, GptAccessDecision decision) async {
    if (!GptMcpNode.instance.isStarted) return;
    final result = await GptMcpNode.instance.access.decide(requestId, decision);
    result.when(
      ok: (_) => updateState(data.copyWith(clearError: true)),
      err: (failure) => updateState(data.copyWith(error: failure.message)),
    );
    await refresh();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

mixin GptMcpNodeService {
  static final ReactiveNotifier<GptMcpNodeViewModel> instance =
      ReactiveNotifier<GptMcpNodeViewModel>(() => GptMcpNodeViewModel());
}
