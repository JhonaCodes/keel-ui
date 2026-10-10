import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/keel_remote/model/live_session.dart';
import 'package:keel_ui/src/modules/keel_remote/repository/live_sessions_repository.dart';

/// What every node reports it is running: sessions, Keel AI answering,
/// deploys, jobs…
class LiveSessionsViewModel extends ViewModel<LiveSessionsState> {
  LiveSessionsViewModel() : super(const LiveSessionsState());

  LiveSessionsRepository get _repository => const LiveSessionsRepository();

  int _generation = 0;

  @override
  void init() {}

  /// Reads the report again; what is on screen stays while it reads.
  Future<void> refresh() async {
    final generation = ++_generation;
    transformState((state) => state.copyWith(loading: true));
    final result = await _repository.list();
    if (generation != _generation || isDisposed) return;
    result.when(
      ok: (sessions) => transformState(
        (state) => state.copyWith(
          sessions: sessions,
          loading: false,
          clearFailure: true,
        ),
      ),
      err: (failure) => transformState(
        (state) => state.copyWith(loading: false, failure: failure),
      ),
    );
  }

  /// Forgets what the previous session showed.
  void clear() {
    _generation++;
    updateState(const LiveSessionsState());
  }
}

mixin LiveSessionsService {
  static final ReactiveNotifier<LiveSessionsViewModel> instance =
      ReactiveNotifier<LiveSessionsViewModel>(LiveSessionsViewModel.new);
}
