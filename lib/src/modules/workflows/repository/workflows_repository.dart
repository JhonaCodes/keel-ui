import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

class WorkflowsRepository {
  static const _prefix = 'workflow_';

  Future<List<Workflow>> load() async {
    final records = await LocalDatabase.getAllWithPrefix(_prefix);
    return records.map(Workflow.fromJson).toList();
  }

  Future<void> save(List<Workflow> workflows) async {
    await LocalDatabase.replaceAllWithPrefix(
      _prefix,
      workflows.map((workflow) => workflow.toJson()).toList(),
    );
  }
}
