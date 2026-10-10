import 'dart:async';

import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/integrations/keel_api/keel_api.dart';
import 'package:keel_ui/src/modules/keel_remote/model/remote_tasks_state.dart';
import 'package:keel_ui/src/modules/keel_remote/repository/remote_tasks_repository.dart';
import 'package:keel_ui/src/modules/keel_remote/viewmodel/remote_tasks_viewmodel.dart';

/// The one remote task the central area follows.
///
/// While its view is on screen ([watch]) the task and its history are read
/// again every [pollEvery] through [refresh], which lands the new reading
/// over the old one — the view never falls back to a loading state between
/// two reads. Polling stops once the task is terminal, and whenever the view
/// leaves ([unwatch]).
class RemoteTaskViewModel extends ViewModel<RemoteTaskFollowState> {
  RemoteTaskViewModel() : super(const RemoteTaskFollowState());

  static const Duration pollEvery = Duration(seconds: 3);

  RemoteTasksRepository get _repository => const RemoteTasksRepository();

  Timer? _timer;
  bool _watching = false;

  /// Bumped when what is followed changes, so a reading of the previous task
  /// never lands on the next one.
  int _generation = 0;

  @override
  void init() {}

  /// Follows [taskId] from now on.
  void follow(String taskId) {
    if (data.taskId != taskId) {
      _generation++;
      updateState(RemoteTaskFollowState(taskId: taskId, loading: true));
    }
    unawaited(refresh());
    _schedule();
  }

  /// The view is on screen: keep reading.
  void watch() {
    _watching = true;
    _schedule();
  }

  /// The view left: stop reading.
  void unwatch() {
    _watching = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Reads the task and its history again and lands them over what is shown.
  Future<void> refresh() async {
    final taskId = data.taskId;
    if (taskId == null) return;
    final generation = _generation;
    final (task, events) = await (
      _repository.byId(taskId),
      _repository.events(taskId),
    ).wait;
    if (generation != _generation || isDisposed) return;
    task.when(
      ok: (task) => transformState(
        (state) => state.copyWith(
          task: task,
          events: events.when(ok: (events) => events, err: (_) => null),
          loading: false,
          clearFailure: true,
        ),
      ),
      err: (failure) => transformState(
        (state) => state.copyWith(loading: false, failure: failure),
      ),
    );
    if (data.task?.isTerminal ?? false) {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Cancels the followed task. Null when it worked.
  Future<KeelApiFailure?> cancel() async {
    final taskId = data.taskId;
    if (taskId == null) return null;
    final failure = await RemoteTasksService.instance.notifier.cancel(taskId);
    await refresh();
    return failure;
  }

  /// Forgets what the previous session showed.
  void clear() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    updateState(const RemoteTaskFollowState());
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (!_watching || data.taskId == null || (data.task?.isTerminal ?? false)) {
      return;
    }
    _timer = Timer.periodic(pollEvery, (_) => unawaited(refresh()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

mixin RemoteTaskService {
  static final ReactiveNotifier<RemoteTaskViewModel> instance =
      ReactiveNotifier<RemoteTaskViewModel>(RemoteTaskViewModel.new);
}
