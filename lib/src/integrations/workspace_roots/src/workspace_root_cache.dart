part of '../workspace_roots.dart';

const _rootsPrefix = 'workspace_root_';

/// Cuántas rutas se recuerdan. Es una lista para elegir, no un historial:
/// pasadas dos docenas nadie la lee, y la de abajo de todo ya no dice nada.
const _rootsCapacity = 30;

class _WorkspaceRootsRepository {
  Future<List<WorkspaceRoot>> load() async {
    final records = await LocalDatabase.getAllWithPrefix(_rootsPrefix);
    return records.map(WorkspaceRoot.fromJson).toList();
  }

  Future<void> save(List<WorkspaceRoot> roots) {
    return LocalDatabase.replaceAllWithPrefix(
      _rootsPrefix,
      roots.map((root) => root.toJson()).toList(),
    );
  }
}

/// Las carpetas donde este usuario trabaja, más recientes primero.
///
/// Se alimenta sola de dos lados: cada vez que se elige una carpeta en un
/// selector, y cada vez que un proyecto declara su directorio de trabajo.
/// Nadie la administra a mano.
class WorkspaceRootsViewModel extends ViewModel<WorkspaceRootsState> {
  WorkspaceRootsViewModel() : super(const WorkspaceRootsState());

  final _repository = _WorkspaceRootsRepository();

  Future<void>? _ready;
  Future<void> get ready => _ready ??= _load();

  @override
  void init() {
    if (_ready == null) updateSilently(const WorkspaceRootsState());
    unawaited(ready);
  }

  Future<void> _load() async {
    try {
      final roots = await _repository.load()
        ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
      updateState(data.copyWith(roots: roots));
    } catch (error) {
      Log.e('No pude leer las carpetas recientes', error: error);
    }
  }

  /// Las rutas conocidas, de la más reciente a la más vieja.
  List<String> get recentPaths => [for (final root in data.roots) root.path];

  /// Dónde abrir un selector de carpeta que no tiene un valor previo.
  String? get lastUsedPath => data.roots.firstOrNull?.path;

  /// Anota que se usó [path]. Repetirlo lo sube al tope en vez de duplicarlo.
  ///
  /// Una ruta que ya no existe no se anota: la lista sirve para ofrecer
  /// lugares a los que se puede ir, y un disco desmontado no es uno.
  Future<void> remember(String path) async {
    final clean = path.trim();
    if (clean.isEmpty) return;
    await ready;
    if (!Directory(clean).existsSync()) return;

    final now = DateTime.now();
    final roots = [
      WorkspaceRoot(path: clean, lastUsedAt: now),
      for (final root in data.roots)
        if (root.path != clean) root,
    ];
    final bounded = roots.take(_rootsCapacity).toList(growable: false);
    updateState(data.copyWith(roots: bounded));
    unawaited(_save(bounded));
  }

  Future<void> forget(String path) async {
    await ready;
    if (!data.roots.any((root) => root.path == path)) return;
    final roots = [
      for (final root in data.roots)
        if (root.path != path) root,
    ];
    updateState(data.copyWith(roots: roots));
    unawaited(_save(roots));
  }

  /// Todo lugar razonable para buscar algo: primero lo que el usuario usó,
  /// después los volúmenes montados que todavía no aparecieron.
  ///
  /// El orden importa — es el que ve tanto el selector como el agente, y lo
  /// que el usuario tocó ayer vale más que un disco que existe.
  List<String> knownRoots() {
    final roots = <String>[...recentPaths];
    for (final volume in mountedVolumeRoots()) {
      if (roots.any((root) => root == volume)) continue;
      roots.add(volume);
    }
    return roots;
  }

  Future<void> _save(List<WorkspaceRoot> roots) async {
    try {
      await _repository.save(roots);
    } catch (error) {
      Log.e('No pude guardar las carpetas recientes', error: error);
    }
  }
}

mixin WorkspaceRootsService {
  static final ReactiveNotifier<WorkspaceRootsViewModel> instance =
      ReactiveNotifier<WorkspaceRootsViewModel>(
        () => WorkspaceRootsViewModel(),
      );
}
