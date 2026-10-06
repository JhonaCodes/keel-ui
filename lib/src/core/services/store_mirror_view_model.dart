import 'package:keel_core/engine/state_holder.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

/// A ViewModel over a keel_core store: the store owns the state and the
/// logic (the same engine keel-server runs); this keeps widgets and tests
/// reading and writing that state exactly as before.
///
/// Writes go to the store; the store's changes come back here and rebuild.
abstract class StoreMirrorViewModel<T> extends ViewModel<T> {
  StoreMirrorViewModel(this.store) : super(store.data);

  final StateHolder<T> store;

  @override
  void init() {
    super.updateSilently(store.data);
    store.changes.listen(super.updateState);
  }

  @override
  void updateState(T newState) => store.updateState(newState);

  @override
  void updateSilently(T newState) {
    store.updateSilently(newState);
    super.updateSilently(newState);
  }

  @override
  void transformState(T Function(T data) transformer) =>
      updateState(transformer(store.data));

  @override
  void transformStateSilently(T Function(T data) transformer) =>
      updateSilently(transformer(store.data));
}
