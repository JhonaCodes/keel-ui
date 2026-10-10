import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:result_controller/result_controller.dart';

import 'package:keel_ui/src/integrations/keel_api/keel_api.dart';
import 'package:keel_ui/src/modules/keel_remote/model/remote_task.dart';
import 'package:keel_ui/src/modules/keel_remote/model/remote_tasks_state.dart';
import 'package:keel_ui/src/modules/keel_remote/repository/remote_tasks_repository.dart';
import 'package:keel_ui/src/modules/keel_remote/viewmodel/keel_nodes_viewmodel.dart';

/// The task queue of the Keel API: one page, a status filter, creating a
/// task for an online node and cancelling one.
class RemoteTasksViewModel extends ViewModel<RemoteTasksState> {
  RemoteTasksViewModel() : super(const RemoteTasksState());

  RemoteTasksRepository get _repository => const RemoteTasksRepository();

  int _generation = 0;

  @override
  void init() {}

  /// Reads the page again with the current filter. The tasks on screen stay
  /// while it reads — no blank list between two reads.
  Future<void> refresh() async {
    final generation = ++_generation;
    transformState((state) => state.copyWith(loading: true));
    final result = await _repository.list(status: data.filter);
    if (generation != _generation || isDisposed) return;
    result.when(
      ok: (tasks) => transformState(
        (state) =>
            state.copyWith(tasks: tasks, loading: false, clearFailure: true),
      ),
      err: (failure) => transformState(
        (state) => state.copyWith(loading: false, failure: failure),
      ),
    );
  }

  /// Shows only [status]; null shows every status.
  Future<void> filterBy(RemoteTaskStatus? status) async {
    if (status == data.filter) return;
    transformState(
      (state) => state.copyWith(filter: status, clearFilter: status == null),
    );
    await refresh();
  }

  /// Why [draft] cannot be sent yet, or null. The node has to be online now:
  /// a task for a node that is gone waits in the queue for nobody.
  RemoteTaskDraftProblem? problemOf(RemoteTaskDraft draft) {
    if (draft.type.trim().isEmpty) return RemoteTaskDraftProblem.missingType;
    if (!KeelJson.isObject(draft.payloadJson)) {
      return RemoteTaskDraftProblem.payloadNotObject;
    }
    if (!KeelNodesService.instance.notifier.data.isOnlineWorker(draft.nodeId)) {
      return RemoteTaskDraftProblem.nodeNotOnline;
    }
    return null;
  }

  /// Queues [draft]; the new task goes to the top of the list.
  Future<Result<RemoteTask, KeelApiFailure>> create(
    RemoteTaskDraft draft,
  ) async {
    if (problemOf(draft) != null) {
      return Err(const KeelApiFailure(kind: KeelApiFailureKind.badRequest));
    }
    final result = await _repository.create(draft);
    result.when(
      ok: (task) => transformState(
        (state) => state.copyWith(
          tasks: <RemoteTask>[
            task,
            ...state.tasks.where((existing) => existing.id != task.id),
          ],
        ),
      ),
      err: (_) {},
    );
    return result;
  }

  /// Cancels [taskId]; the list shows it cancelled.
  Future<KeelApiFailure?> cancel(String taskId) async {
    final result = await _repository.cancel(taskId);
    return result.when(
      ok: (task) {
        _replace(task);
        return null;
      },
      err: (failure) => failure,
    );
  }

  void _replace(RemoteTask task) => transformState(
    (state) => state.copyWith(
      tasks: <RemoteTask>[
        for (final existing in state.tasks)
          existing.id == task.id ? task : existing,
      ],
    ),
  );

  /// Forgets what the previous session showed.
  void clear() {
    _generation++;
    updateState(const RemoteTasksState());
  }
}

mixin RemoteTasksService {
  static final ReactiveNotifier<RemoteTasksViewModel> instance =
      ReactiveNotifier<RemoteTasksViewModel>(RemoteTasksViewModel.new);
}
