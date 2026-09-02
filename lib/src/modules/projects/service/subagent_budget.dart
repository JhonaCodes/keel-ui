/// Reserves subagents against the node that opens them.
///
/// The policy belongs to the user message that started the workflow, but the
/// budget cannot: a workflow runs several nodes and each delegates for its own
/// reasons — the charter inventories impact, the implementation verifies. One
/// budget for the whole run let the first node starve every node after it, so
/// the key is the pair (root turn, node). Keeping this state separate from the
/// prompt makes the limit observable by the event consumer.
class SubagentBudget {
  final Map<String, int> _acceptedByScope = {};

  /// [workNodeId] is null outside a workflow — a 1:1 chat has a single scope,
  /// which is the turn itself.
  bool tryReserve({
    required String turnId,
    required int maxSubagents,
    String? workNodeId,
  }) {
    if (maxSubagents <= 0) return false;
    final scope = _scopeKey(turnId, workNodeId);
    final accepted = _acceptedByScope[scope] ?? 0;
    if (accepted >= maxSubagents) return false;
    _acceptedByScope[scope] = accepted + 1;
    return true;
  }

  void clear() => _acceptedByScope.clear();

  static String _scopeKey(String turnId, String? workNodeId) =>
      workNodeId == null || workNodeId.isEmpty
      ? turnId
      : '$turnId::$workNodeId';
}
