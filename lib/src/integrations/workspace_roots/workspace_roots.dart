/// El ViewModel sobre `WorkspaceRootsRepository` (keel_core): alimenta la
/// sección PROYECTOS CONOCIDOS del prompt de un agente sin proyecto, y el
/// selector de carpeta, con las rutas que este usuario ya usó más los
/// volúmenes montados que todavía no aparecieron.
///
/// Mirror delgado de `WorkspaceRootsStore` (keel_core): toda la lógica real
/// vive ahí.
library;

import 'package:keel_core/integrations/workspace_roots/service/workspace_roots_store.dart';
import 'package:keel_core/integrations/workspace_roots/workspace_roots.dart';
import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:keel_ui/src/core/services/store_mirror_view_model.dart';

class WorkspaceRootsViewModel
    extends StoreMirrorViewModel<WorkspaceRootsState> {
  WorkspaceRootsViewModel() : super(WorkspaceRootsStore.instance);

  /// Resuelve cuando ya se cargaron las carpetas persistidas.
  Future<void> get ready => WorkspaceRootsStore.instance.ready;

  /// Las rutas conocidas, de la más reciente a la más vieja.
  List<String> get recentPaths => WorkspaceRootsStore.instance.recentPaths;

  /// Dónde abrir un selector de carpeta que no tiene un valor previo.
  String? get lastUsedPath => WorkspaceRootsStore.instance.lastUsedPath;

  /// Anota que se usó [path]. Repetirlo lo sube al tope en vez de duplicarlo.
  Future<void> remember(String path) =>
      WorkspaceRootsStore.instance.remember(path);

  Future<void> forget(String path) => WorkspaceRootsStore.instance.forget(path);

  /// Todo lugar razonable para buscar algo: primero lo que el usuario usó,
  /// después los volúmenes montados que todavía no aparecieron.
  List<String> knownRoots() => WorkspaceRootsStore.instance.knownRoots();
}

mixin WorkspaceRootsService {
  static final ReactiveNotifier<WorkspaceRootsViewModel> instance =
      ReactiveNotifier<WorkspaceRootsViewModel>(
        () => WorkspaceRootsViewModel(),
      );
}
