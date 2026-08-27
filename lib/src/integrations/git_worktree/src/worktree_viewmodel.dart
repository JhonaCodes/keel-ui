part of '../git_worktree.dart';

/// Cada cuánto se vuelve a preguntar dónde estamos parados.
///
/// Un worktree no cambia mientras mirás la pantalla, pero la RAMA sí: la
/// cambiás vos en una terminal, o la cambia el agente en su turno. Leerlo es
/// una llamada a git; mostrar una rama vieja es peor.
const _kPlaceTtl = Duration(seconds: 20);

class WorktreeState {
  const WorktreeState({
    this.places = const {},
    this.busy = false,
    this.plan,
    this.report,
  });

  /// Dónde está parado cada directorio de trabajo, por ruta.
  final Map<String, WorktreePlace> places;

  final bool busy;

  /// Lo que está por pasar, mientras el panel está abierto.
  final WorktreeUnifyPlan? plan;

  /// Lo que pasó. Se queda a la vista: una operación que borra una carpeta
  /// se lee después, no se adivina.
  final WorktreeUnifyReport? report;

  WorktreeState copyWith({
    Map<String, WorktreePlace>? places,
    bool? busy,
    WorktreeUnifyPlan? plan,
    WorktreeUnifyReport? report,
    bool clearPlan = false,
    bool clearReport = false,
  }) => WorktreeState(
    places: places ?? this.places,
    busy: busy ?? this.busy,
    plan: clearPlan ? null : (plan ?? this.plan),
    report: clearReport ? null : (report ?? this.report),
  );
}

/// Dónde corre cada proyecto y cómo volver al worktree principal.
///
/// Cachea por ruta y no por proyecto a propósito: dos proyectos registrados
/// sobre la misma carpeta son la misma pregunta, y el que la haga segundo no
/// tiene por qué pagarla de nuevo.
class WorktreeViewModel extends ViewModel<WorktreeState> {
  WorktreeViewModel() : super(const WorktreeState());

  @override
  void init() {}

  final Map<String, DateTime> _readAt = {};
  final Set<String> _inFlight = {};

  String _key(String dir) => dir.trim();

  /// Lo último que se leyó de [dir], o null si nunca se preguntó.
  WorktreePlace? placeOf(String dir) => data.places[_key(dir)];

  bool _isStale(String key) {
    final read = _readAt[key];
    return read == null || DateTime.now().difference(read) > _kPlaceTtl;
  }

  /// Lee [dir] si hace falta y devuelve lo que sepamos de ese lugar.
  Future<WorktreePlace> ensure(String dir, {bool force = false}) async {
    final key = _key(dir);
    if (key.isEmpty) return WorktreePlace(dir: dir);

    final cached = data.places[key];
    if (!force && cached != null && !_isStale(key)) return cached;

    final place = await readWorktreePlace(key);
    _readAt[key] = DateTime.now();
    // Solo se avisa si CAMBIÓ. Con una lectura cada veinte segundos por
    // proyecto abierto, publicar lo mismo sería redibujar la pantalla para
    // nada.
    if (place != cached) {
      updateState(data.copyWith(places: {...data.places, key: place}));
    }
    return place;
  }

  /// Para la UI: pide una lectura si la que hay está vieja, sin esperarla.
  void watch(String dir) {
    final key = _key(dir);
    if (key.isEmpty || !_isStale(key) || _inFlight.contains(key)) return;
    _inFlight.add(key);
    unawaited(ensure(key).whenComplete(() => _inFlight.remove(key)));
  }

  /// Arma el plan de unificación de [project]. No toca nada.
  Future<void> prepare(Project project) async {
    updateState(data.copyWith(busy: true, clearPlan: true, clearReport: true));
    try {
      final place = await ensure(project.workingDirectory, force: true);
      final running = runningSessionsOf(project);
      final plan = await planUnify(place, running: running);
      updateState(data.copyWith(busy: false, plan: plan));
    } catch (error) {
      Log.e('No pude leer el worktree del proyecto', error: error);
      updateState(data.copyWith(busy: false));
    }
  }

  /// Trae la rama al principal, saca la carpeta y muda el proyecto.
  ///
  /// El proyecto cambia de directorio en cuanto la carpeta vieja deja de
  /// existir, salga bien el resto o no: dejarlo apuntando a lo que se borró
  /// es la única forma de que esto termine peor de lo que empezó.
  Future<void> unify(Project project) async {
    final plan = data.plan;
    if (plan == null || !plan.canRun || data.busy) return;

    updateState(data.copyWith(busy: true, clearReport: true));
    final report = await AppStatusService.instance.notifier.during(
      'Unificando el worktree',
      () => unifyWorktree(plan),
    );

    if (report.moved) {
      ProjectsService.instance.notifier.setProjectWorkingDirectory(
        project.id,
        report.path,
      );
      final places = {...data.places}..remove(_key(plan.from.path));
      _readAt.remove(_key(plan.from.path));
      updateState(data.copyWith(places: places));
      await ensure(report.path, force: true);
    }

    updateState(data.copyWith(busy: false, report: report, clearPlan: true));
  }

  /// Cierra lo que quedó en pantalla. Lo llama el panel al salir: el próximo
  /// que lo abra arma su propio plan.
  void forget() {
    if (data.plan == null && data.report == null && !data.busy) return;
    updateState(data.copyWith(clearPlan: true, clearReport: true));
  }
}

mixin WorktreeService {
  static final ReactiveNotifier<WorktreeViewModel> instance =
      ReactiveNotifier<WorktreeViewModel>(() => WorktreeViewModel());
}
