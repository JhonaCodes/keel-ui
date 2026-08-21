import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/rules/model/rule.dart';

class RulesRepository {
  static const _prefix = 'rule_';

  Future<List<Rule>> load() async {
    final records = await LocalDatabase.getAllWithPrefix(_prefix);
    return records.map(Rule.fromJson).toList();
  }

  Future<void> save(List<Rule> rules) async {
    await LocalDatabase.replaceAllWithPrefix(
      _prefix,
      rules.map((rule) => rule.toJson()).toList(),
    );
  }
}
