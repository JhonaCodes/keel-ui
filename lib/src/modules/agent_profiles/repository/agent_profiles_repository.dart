import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';

class AgentProfilesRepository {
  static const _prefix = 'profile_';

  Future<List<AgentProfile>> load() async {
    final records = await LocalDatabase.getAllWithPrefix(_prefix);
    return records.map(AgentProfile.fromJson).toList();
  }

  Future<void> save(List<AgentProfile> profiles) async {
    await LocalDatabase.replaceAllWithPrefix(
      _prefix,
      profiles.map((profile) => profile.toJson()).toList(),
    );
  }
}
