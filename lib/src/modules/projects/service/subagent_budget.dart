/// Reserves subagents against the root turn that owns them.
///
/// A workflow can run more than one node, but its subagent policy belongs to
/// the user message that started the workflow. Keeping this state separate
/// from the prompt makes the limit enforceable by the event consumer.
class SubagentBudget {
  final Map<String, int> _acceptedByTurnId = {};

  bool tryReserve({required String turnId, required int maxSubagents}) {
    if (maxSubagents <= 0) return false;
    final accepted = _acceptedByTurnId[turnId] ?? 0;
    if (accepted >= maxSubagents) return false;
    _acceptedByTurnId[turnId] = accepted + 1;
    return true;
  }

  void clear() => _acceptedByTurnId.clear();
}
