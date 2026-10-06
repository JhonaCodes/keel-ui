import 'package:keel_core/modules/catalog_locks/model/catalog_lock.dart';
import 'package:keel_core/modules/catalog_locks/service/catalog_locks_store.dart';
import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:keel_ui/src/core/services/store_mirror_view_model.dart';

export 'package:keel_core/modules/catalog_locks/service/catalog_locks_store.dart'
    show kCatalogLockRegistryName;

class CatalogLocksViewModel extends StoreMirrorViewModel<CatalogLocksState> {
  CatalogLocksViewModel() : super(CatalogLocksStore.instance);

  Future<void> get ready => CatalogLocksStore.instance.ready;

  bool isLocked(CatalogLockKind kind, String name) =>
      CatalogLocksStore.instance.isLocked(kind, name);

  Map<CatalogLockKind, List<CatalogLock>> get locksByKind =>
      CatalogLocksStore.instance.locksByKind;

  List<CatalogLock> get userLocks => CatalogLocksStore.instance.userLocks;

  Future<void> setLocked(
    CatalogLockKind kind,
    String name, {
    required bool locked,
  }) => CatalogLocksStore.instance.setLocked(kind, name, locked: locked);

  Future<void> rename(
    CatalogLockKind kind, {
    required String from,
    required String to,
  }) => CatalogLocksStore.instance.rename(kind, from: from, to: to);
}

mixin CatalogLocksService {
  static final ReactiveNotifier<CatalogLocksViewModel> instance =
      ReactiveNotifier<CatalogLocksViewModel>(() => CatalogLocksViewModel());
}
