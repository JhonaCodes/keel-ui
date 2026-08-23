import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/requirements/viewmodel/requirements_viewmodel.dart';
import 'package:keel_ui/src/modules/workspace/model/workspace_lens.dart';

/// El único que navega.
///
/// Cada `openX` hace las DOS cosas que antes estaban separadas: mueve la
/// selección en el ViewModel que corresponde y dice qué lente queda. Ese
/// divorcio era el bug: la fila de una sesión llamaba a `selectSession` y
/// nadie cambiaba el lente, así que tocarla con un tablero abierto no
/// navegaba a ningún lado.
///
/// Los ViewModels de abajo no saben que esto existe, y así queda: seleccionar
/// no es navegar. Un trabajo que entra por la API abre una sesión sin
/// arrastrarte a ella, y eso es lo correcto —no pediste ir.
class WorkspaceViewModel extends ViewModel<WorkspaceState> {
  WorkspaceViewModel() : super(const WorkspaceState());

  @override
  void init() {}

  ProjectsViewModel get _projects => ProjectsService.instance.notifier;

  void openAgent(String agentId) {
    AgentsService.instance.notifier.selectAgent(agentId);
    _show(WorkspaceLens.agent);
  }

  void openRequirement(String requirementId) {
    RequirementsService.instance.notifier.select(requirementId);
    _show(WorkspaceLens.requirement);
  }

  /// Abrir un proyecto lo deja donde lo dejaste: en su sesión si tenía una
  /// abierta, y si no en su estado.
  void openProject(String projectId) {
    _projects.selectProject(projectId);
    final project = _projects.data.projects
        .where((entry) => entry.id == projectId)
        .firstOrNull;
    _show(
      project?.activeSessionId == null
          ? WorkspaceLens.projectState
          : WorkspaceLens.session,
    );
  }

  void openProjectState(String projectId) {
    _projects.showProjectState(projectId);
    _show(WorkspaceLens.projectState);
  }

  void openBoards(String projectId) {
    _projects.selectProject(projectId);
    _show(WorkspaceLens.boards);
  }

  void openBoard(String boardId) {
    updateState(WorkspaceState(lens: WorkspaceLens.board, boardId: boardId));
  }

  /// Va a una sesión concreta de un proyecto concreto.
  ///
  /// Selecciona el PROYECTO además de la sesión: `selectSession` solo marca
  /// cuál está activa dentro del proyecto, y el área central dibuja la del
  /// proyecto seleccionado. Mientras todo lo que llamaba acá venía de un
  /// proyecto ya abierto eso no se notaba; desde un requerimiento —que vive
  /// en otro lente y apunta al proyecto DESTINO— se notaba enseguida.
  void openSession(String projectId, String sessionId) {
    _projects.selectProject(projectId);
    _projects.selectSession(projectId, sessionId);
    _show(WorkspaceLens.session);
  }

  /// Abre una sesión nueva y va a ella. Es el botón, no el alta: crearla
  /// desde la API o desde una tool de Keel AI no mueve lo que estás mirando.
  void openNewSession(String projectId) {
    _projects.selectProject(projectId);
    _projects.createSession(projectId);
    _show(WorkspaceLens.session);
  }

  void _show(WorkspaceLens lens) {
    if (data.lens == lens && data.boardId == null) return;
    updateState(WorkspaceState(lens: lens));
  }
}

mixin WorkspaceService {
  static final ReactiveNotifier<WorkspaceViewModel> instance =
      ReactiveNotifier<WorkspaceViewModel>(() => WorkspaceViewModel());
}
