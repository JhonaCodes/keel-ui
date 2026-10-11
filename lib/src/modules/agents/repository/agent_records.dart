import 'package:keel_core/core/store/keel_store.dart';
import 'package:keel_core/modules/agents/model/agent.dart';
import 'package:keel_core/modules/agents/repository/agents_repository.dart';

/// The two operations on saved conversations that must never touch the
/// rest of them.
///
/// keel-debt: these belong in keel_core's [AgentsRepository] (same `agent_`
/// prefix, kept in sync by hand until they move there). They live here
/// because keel_core is consumed by git ref and the fix could not wait.
extension AgentRecords on AgentsRepository {
  static const _prefix = 'agent_';

  /// Every saved conversation that can be read, plus how many could not.
  ///
  /// [AgentsRepository.load] parses them all in one `map`: a single record
  /// it cannot read throws, and the person ends up with NO conversations at
  /// all — which the Keel AI window took as «there are none» and covered
  /// with a new one.
  Future<({List<Agent> agents, int unreadable})> loadReadable() async {
    final records = await KeelStore.instance!.getAllWithPrefix(_prefix);
    final agents = <Agent>[];
    var unreadable = 0;
    for (final record in records) {
      try {
        agents.add(Agent.fromJson(record));
      } catch (_) {
        unreadable++;
      }
    }
    return (agents: agents, unreadable: unreadable);
  }

  /// Removes ONE conversation.
  ///
  /// Deleting used to rewrite the whole prefix with what was in memory, so
  /// every conversation not loaded at that moment —a slow start, a record
  /// that failed to parse— was deleted along with the one you meant.
  Future<void> deleteOne(String id) =>
      KeelStore.instance!.delete('$_prefix$id');
}
