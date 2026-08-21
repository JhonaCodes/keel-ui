import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/knowledge/model/knowledge_base.dart';

class KnowledgeBasesRepository {
  static const _prefix = 'knowledgebase_';

  Future<List<KnowledgeBase>> load() async {
    final records = await LocalDatabase.getAllWithPrefix(_prefix);
    return records.map(KnowledgeBase.fromJson).toList();
  }

  Future<void> save(List<KnowledgeBase> bases) async {
    await LocalDatabase.replaceAllWithPrefix(
      _prefix,
      bases.map((base) => base.toJson()).toList(),
    );
  }
}
