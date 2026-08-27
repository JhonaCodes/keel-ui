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
    this.release = const InstalledReleaseStatus(),
    this.checking = false,
    this.updating = false,
    this.report,
  });

  final KeelSource source;
  final KeelVersion version;
  final InstalledReleaseStatus release;
  final bool checking;
  final bool updating;

  /// Lo que pasó al traer los commits. Se queda a la vista: después de
  /// actualizar hay algo más que hacer, y esconder el informe es esconder
  /// justo eso.
  final KeelUpdateReport? report;

  /// Si el checkout de desarrollo necesita atención. Es exclusivamente lo
  /// que enciende el punto de Máquina; una release descargable tiene su aviso
  /// propio debajo de Ajustes.
  bool get pending => version.outdated || version.stale;

  AppUpdateState copyWith({
    KeelSource? source,
    KeelVersion? version,
    InstalledReleaseStatus? release,
    bool? checking,
    bool? updating,
    KeelUpdateReport? report,
    bool clearReport = false,
  }) => AppUpdateState(
    source: source ?? this.source,
    version: version ?? this.version,
    release: release ?? this.release,
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
          identical(release, other.release) &&
          identical(report, other.report);

  @override
  int get hashCode => Object.hash(
    source.root,
    version.head,
    version.behind,
    release.current,
    release.latest?.release,
    checking,
    updating,
    report,
  );
}

/// Qué código estás corriendo y cómo pasarte al nuevo.
class AppUpdateViewModel extends ViewModel<AppUpdateState> {
  AppUpdateViewModel({Future<InstalledReleaseStatus> Function()? releaseReader})
    : _releaseReader = releaseReader ?? readInstalledRelease,
      super(const AppUpdateState());

  final Future<InstalledReleaseStatus> Function() _releaseReader;

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
    running: totalRunningWork(
      projects: ProjectsService.instance.notifier.data.projects,
      agents: const [],
    ),
  );

  /// Mira si hay algo nuevo. Sin [force] respeta [_kCheckTtl].
  Future<void> check({bool force = false}) async {
    if (data.checking) return;

    final last = data.release.checkedAt ?? data.version.checkedAt;
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
    final releaseFuture = _releaseReader();
    var version = data.version;
    try {
      version = await readKeelVersion(source);
    } catch (error) {
      Log.e('No pude revisar si hay una versión nueva de Keel', error: error);
    }
    InstalledReleaseStatus release;
    try {
      release = await releaseFuture;
    } on Object catch (error) {
      Log.e('No pude revisar el canal de releases de Keel', error: error);
      release = InstalledReleaseStatus(
        current: data.release.current,
        checkedAt: DateTime.now(),
        error: 'No pude revisar la última versión: $error',
      );
    }
    updateState(
      data.copyWith(version: version, release: release, checking: false),
    );
  }

  /// Abre exclusivamente la descarga publicada en el manifiesto oficial.
  Future<void> downloadLatest() async {
    final latest = data.release.latest;
    if (!data.release.updateAvailable || latest == null) return;
    await openExternalUrl(latest.downloadUrl.toString());
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
