import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/agents/model/agent.dart';

class AgentsRepository {
  static const _prefix = 'agent_';

  Future<List<Agent>> load() async {
    final records = await LocalDatabase.getAllWithPrefix(_prefix);
    return records.map(Agent.fromJson).toList();
  }

  Future<void> save(List<Agent> agents) async {
    await LocalDatabase.replaceAllWithPrefix(
      _prefix,
      agents.map((agent) => agent.toJson()).toList(),
    );
  }
}
