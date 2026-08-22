import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/requirements/model/internal_requirement.dart';

class RequirementsRepository {
  static const _prefix = 'requirement_';

  Future<List<InternalRequirement>> load() async {
    final records = await LocalDatabase.getAllWithPrefix(_prefix);
    return records.map(InternalRequirement.fromJson).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> save(List<InternalRequirement> requirements) async {
    await LocalDatabase.replaceAllWithPrefix(
      _prefix,
      requirements.map((requirement) => requirement.toJson()).toList(),
    );
  }
}
