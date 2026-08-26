import 'dart:async';

import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/catalog_locks/model/catalog_lock.dart';
import 'package:keel_ui/src/modules/catalog_locks/repository/catalog_locks_repository.dart';

/// The system entry makes every tool-mediated registry mutation permissioned.
const kCatalogLockRegistryName = 'registry';

class CatalogLocksViewModel extends ViewModel<CatalogLocksState> {
  CatalogLocksViewModel() : super(const CatalogLocksState());

  CatalogLocksRepository get _repository => CatalogLocksRepository();

  Future<void>? _ready;
  Future<void> get ready => _ready ??= _load();

  @override
  void init() {
    if (_ready == null) updateSilently(const CatalogLocksState());
    unawaited(ready);
  }

  Future<void> _load() async {
    try {
      final loaded = await _repository.load();
      final locks = _withRegistryLock(loaded);
      updateState(data.copyWith(locks: locks));
      if (locks.length != loaded.length) await _repository.save(locks);
    } catch (error) {
      Log.e('Failed to load catalog locks', error: error);
    }
  }

  bool isLocked(CatalogLockKind kind, String name) =>
      data.locks.any((entry) => entry.kind == kind && entry.name == name);

  /// Los candados que puso el usuario, agrupados por tipo y ordenados por
  /// nombre — el orden del enum para los grupos, alfabético adentro de cada
  /// uno. Es lo que muestra la pantalla de bloqueados.
  ///
  /// El registro de candados queda AFUERA: existe siempre, se re-crea solo
  /// ([_withRegistryLock]) y no se saca desde la lista. Mezclarlo con lo que
  /// eligió el usuario haría creer que se puede.
  Map<CatalogLockKind, List<CatalogLock>> get locksByKind {
    final grouped = <CatalogLockKind, List<CatalogLock>>{};
    for (final lock in userLocks) {
      grouped.putIfAbsent(lock.kind, () => []).add(lock);
    }
    for (final locks in grouped.values) {
      locks.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }
    // Se reconstruye en el orden del enum: `grouped` quedó en el orden en
    // que aparecieron los candados, que es el de la base y no significa nada.
    final ordered = <CatalogLockKind, List<CatalogLock>>{};
    for (final kind in CatalogLockKind.values) {
      final locks = grouped[kind];
      if (locks != null) ordered[kind] = locks;
    }
    return ordered;
  }

  /// Todo lo bloqueado menos la entrada del sistema.
  List<CatalogLock> get userLocks => [
    for (final lock in data.locks)
      if (lock.kind != CatalogLockKind.lockRegistry) lock,
  ];

  /// Direct user action from the UI. Tool calls must first obtain approval.
  Future<void> setLocked(
    CatalogLockKind kind,
    String name, {
    required bool locked,
  }) async {
    final normalized = name.trim();
    if (normalized.isEmpty) return;
    final current = data.locks;
    final exists = isLocked(kind, normalized);
    if (exists == locked) return;
    final locks = locked
        ? [
            ...current,
            CatalogLock(
              kind: kind,
              name: normalized,
              createdAt: DateTime.now(),
            ),
          ]
        : current
              .where(
                (entry) => !(entry.kind == kind && entry.name == normalized),
              )
              .toList();
    final ensured = _withRegistryLock(locks);
    updateState(data.copyWith(locks: ensured));
    await _repository.save(ensured);
  }

  /// Keeps the protection attached when a protected catalog item is renamed.
  Future<void> rename(
    CatalogLockKind kind, {
    required String from,
    required String to,
  }) async {
    final oldName = from.trim();
    final newName = to.trim();
    if (oldName.isEmpty || newName.isEmpty || oldName == newName) return;
    if (!isLocked(kind, oldName)) return;

    final renamed = [
      for (final entry in data.locks)
        if (entry.kind == kind && entry.name == oldName)
          CatalogLock(kind: kind, name: newName, createdAt: entry.createdAt)
        else
          entry,
    ];
    final ensured = _withRegistryLock(renamed);
    updateState(data.copyWith(locks: ensured));
    await _repository.save(ensured);
  }

  List<CatalogLock> _withRegistryLock(List<CatalogLock> locks) {
    if (locks.any(
      (entry) =>
          entry.kind == CatalogLockKind.lockRegistry &&
          entry.name == kCatalogLockRegistryName,
    )) {
      return locks;
    }
    return [
      ...locks,
      CatalogLock(
        kind: CatalogLockKind.lockRegistry,
        name: kCatalogLockRegistryName,
        createdAt: DateTime.now(),
      ),
    ];
  }
}

mixin CatalogLocksService {
  static final ReactiveNotifier<CatalogLocksViewModel> instance =
      ReactiveNotifier<CatalogLocksViewModel>(() => CatalogLocksViewModel());
}
