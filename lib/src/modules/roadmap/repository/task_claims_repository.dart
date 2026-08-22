import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/roadmap/model/task_claim.dart';

class TaskClaimsRepository {
  static const _prefix = 'claim_';

  Future<List<TaskClaim>> load() async {
    final records = await LocalDatabase.getAllWithPrefix(_prefix);
    return records.map(TaskClaim.fromJson).toList();
  }

  Future<void> save(List<TaskClaim> claims) async {
    await LocalDatabase.replaceAllWithPrefix(
      _prefix,
      claims.map((claim) => claim.toJson()).toList(),
    );
  }
}
