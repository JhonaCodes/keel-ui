import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/skills/model/skill.dart';

class SkillsRepository {
  static const _prefix = 'skill_';

  Future<List<Skill>> load() async {
    final records = await LocalDatabase.getAllWithPrefix(_prefix);
    return records.map(Skill.fromJson).toList();
  }

  Future<void> save(List<Skill> skills) async {
    await LocalDatabase.replaceAllWithPrefix(
      _prefix,
      skills.map((skill) => skill.toJson()).toList(),
    );
  }
}
