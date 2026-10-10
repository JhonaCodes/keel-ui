import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/keel_remote/model/keel_nodes_state.dart';
import 'package:keel_ui/src/modules/keel_remote/repository/keel_nodes_repository.dart';

/// Every node enrolled with the Keel API and whether it is online now.
class KeelNodesViewModel extends ViewModel<KeelNodesState> {
  KeelNodesViewModel() : super(const KeelNodesState());

  KeelNodesRepository get _repository => const KeelNodesRepository();

  /// Bumped by every read and by [clear]: only the latest read lands, and a
  /// read that started under another session never does.
  int _generation = 0;

  @override
  void init() {}

  /// Reads the nodes again. The ones on screen stay while it reads, and
  /// stay when it fails.
  Future<void> refresh() async {
    final generation = ++_generation;
    transformState((state) => state.copyWith(loading: true));
    final result = await _repository.list();
    if (generation != _generation || isDisposed) return;
    result.when(
      ok: (nodes) => transformState(
        (state) =>
            state.copyWith(nodes: nodes, loading: false, clearFailure: true),
      ),
      err: (failure) => transformState(
        (state) => state.copyWith(loading: false, failure: failure),
      ),
    );
  }

  /// Forgets what the previous session showed.
  void clear() {
    _generation++;
    updateState(const KeelNodesState());
  }
}

mixin KeelNodesService {
  static final ReactiveNotifier<KeelNodesViewModel> instance =
      ReactiveNotifier<KeelNodesViewModel>(KeelNodesViewModel.new);
}
