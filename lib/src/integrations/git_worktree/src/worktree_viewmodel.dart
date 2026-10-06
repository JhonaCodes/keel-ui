part of '../git_worktree.dart';

/// Dónde corre cada proyecto y cómo volver al worktree principal.
///
/// Mirror delgado de [WorktreeStore] (keel_core): cachea lectura y UI, pero
/// el estado real vive en el store. `unify` es la excepción: trae la rama al
/// worktree principal y después muda el [Project] que apunta a esa carpeta,
/// lo que exige escribir en [ProjectsService] (otro workstream) y avisar con
/// [AppStatusService] (un `ReactiveNotifier` de keel-ui). Ninguna de las dos
/// cosas puede vivir en un paquete Dart puro, así que esta orquestación se
/// queda acá — ver la nota en `worktree_store.dart`.
class WorktreeViewModel extends StoreMirrorViewModel<WorktreeState> {
  WorktreeViewModel() : super(WorktreeStore.instance);

  /// Lo último que se leyó de [dir], o null si nunca se preguntó.
  WorktreePlace? placeOf(String dir) => WorktreeStore.instance.placeOf(dir);

  /// Lee [dir] si hace falta y devuelve lo que sepamos de ese lugar.
  Future<WorktreePlace> ensure(String dir, {bool force = false}) =>
      WorktreeStore.instance.ensure(dir, force: force);

  /// Para la UI: pide una lectura si la que hay está vieja, sin esperarla.
  void watch(String dir) => WorktreeStore.instance.watch(dir);

  /// Arma el plan de unificación de [project]. No toca nada.
  Future<void> prepare(Project project) =>
      WorktreeStore.instance.prepare(project);

  /// Trae la rama al principal, saca la carpeta y muda el proyecto.
  ///
  /// El proyecto cambia de directorio en cuanto la carpeta vieja deja de
  /// existir, salga bien el resto o no: dejarlo apuntando a lo que se borró
  /// es la única forma de que esto termine peor de lo que empezó.
  Future<void> unify(Project project) async {
    final store = WorktreeStore.instance;
    final plan = store.data.plan;
    if (plan == null || !plan.canRun || store.data.busy) return;

    store.updateState(store.data.copyWith(busy: true, clearReport: true));
    final report = await AppStatusService.instance.notifier.during(
      'Unificando el worktree',
      () => unifyWorktree(plan),
    );

    if (report.moved) {
      ProjectsService.instance.notifier.setProjectWorkingDirectory(
        project.id,
        report.path,
      );
      store.forgetPlace(plan.from.path);
      await store.ensure(report.path, force: true);
    }

    store.updateState(
      store.data.copyWith(busy: false, report: report, clearPlan: true),
    );
  }

  /// Cierra lo que quedó en pantalla. Lo llama el panel al salir: el próximo
  /// que lo abra arma su propio plan.
  void forget() => WorktreeStore.instance.forget();
}

mixin WorktreeService {
  static final ReactiveNotifier<WorktreeViewModel> instance =
      ReactiveNotifier<WorktreeViewModel>(() => WorktreeViewModel());
}
