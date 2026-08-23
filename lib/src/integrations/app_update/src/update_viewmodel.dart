part of '../app_update.dart';

/// Cada cuánto se le vuelve a preguntar al remoto por su cuenta.
///
/// Seis horas: un proyecto que se mueve todos los días no publica commits
/// cada media hora, y cada revisión es un `git fetch` de verdad. El botón
/// de "Revisar" ignora esto, que es para lo que existe.
const _kCheckTtl = Duration(hours: 6);

class AppUpdateState {
  const AppUpdateState({
    this.source = const KeelSource(),
    this.version = const KeelVersion(),
    this.checking = false,
    this.updating = false,
    this.report,
  });

  final KeelSource source;
  final KeelVersion version;
  final bool checking;
  final bool updating;

  /// Lo que pasó al traer los commits. Se queda a la vista: después de
  /// actualizar hay algo más que hacer, y esconder el informe es esconder
  /// justo eso.
  final KeelUpdateReport? report;

  /// Si hay algo que hacer: commits nuevos, o un binario más viejo que el
  /// código. Es lo que enciende el punto del rail.
  bool get pending => version.outdated || version.stale;

  AppUpdateState copyWith({
    KeelSource? source,
    KeelVersion? version,
    bool? checking,
    bool? updating,
    KeelUpdateReport? report,
    bool clearReport = false,
  }) => AppUpdateState(
    source: source ?? this.source,
    version: version ?? this.version,
    checking: checking ?? this.checking,
    updating: updating ?? this.updating,
    report: clearReport ? null : (report ?? this.report),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUpdateState &&
          checking == other.checking &&
          updating == other.updating &&
          identical(source, other.source) &&
          identical(version, other.version) &&
          identical(report, other.report);

  @override
  int get hashCode => Object.hash(
    source.root,
    version.head,
    version.behind,
    checking,
    updating,
    report,
  );
}

/// Qué código estás corriendo y cómo pasarte al nuevo.
class AppUpdateViewModel extends ViewModel<AppUpdateState> {
  AppUpdateViewModel() : super(const AppUpdateState());

  @override
  void init() {}

  /// El plan de ahora, con las sesiones vivas contadas en el momento.
  ///
  /// Se arma en cada lectura y no se guarda: entre que abrís la pantalla y
  /// tocás el botón puede arrancar un turno, y un plan viejo diría que no
  /// hay ninguno.
  KeelUpdatePlan get plan => KeelUpdatePlan(
    source: data.source,
    version: data.version,
    running: _runningSessions(),
  );

  static int _runningSessions() => ProjectsService.instance.notifier.data
      .projects
      .expand((project) => project.sessions)
      .where((session) => session.isRunning)
      .length;

  /// Mira si hay algo nuevo. Sin [force] respeta [_kCheckTtl].
  Future<void> check({bool force = false}) async {
    if (data.checking) return;

    final last = data.version.checkedAt;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < _kCheckTtl) {
      return;
    }

    // La búsqueda del repo se rehace en cada revisión: es barata y, si la
    // guardáramos, una copia movida de lugar seguiría reportando la ruta
    // vieja para siempre.
    final source = readKeelSource();
    updateState(data.copyWith(source: source, checking: true));
    try {
      final version = await readKeelVersion(source);
      updateState(data.copyWith(version: version, checking: false));
    } catch (error) {
      Log.e('No pude revisar si hay una versión nueva de Keel', error: error);
      updateState(data.copyWith(checking: false));
    }
  }

  /// Trae los commits nuevos. No reconstruye: para eso está [relaunch].
  Future<void> update() async {
    final ready = plan;
    if (!ready.canRun || data.updating) return;

    updateState(data.copyWith(updating: true, clearReport: true));
    final report = await AppStatusService.instance.notifier.during(
      'Trayendo la versión nueva',
      () => runKeelUpdate(ready),
    );
    updateState(data.copyWith(updating: false, report: report));

    // Después del pull el repo está en otro commit: releerlo es lo que hace
    // que la pantalla diga "al día, falta reconstruir" en vez de seguir
    // ofreciendo lo que ya trajo.
    if (report.pulled) await check(force: true);
  }

  /// Abre la Terminal reconstruyendo y cierra Keel.
  Future<void> relaunch() async {
    final ready = plan;
    if (!ready.canRelaunch) return;
    await rebuildAndRelaunch(ready.source.root);
  }

  /// Saca el informe de la pantalla sin tocar nada más.
  void forgetReport() {
    if (data.report == null) return;
    updateState(data.copyWith(clearReport: true));
  }
}

mixin AppUpdateService {
  static final ReactiveNotifier<AppUpdateViewModel> instance =
      ReactiveNotifier<AppUpdateViewModel>(() => AppUpdateViewModel());
}
