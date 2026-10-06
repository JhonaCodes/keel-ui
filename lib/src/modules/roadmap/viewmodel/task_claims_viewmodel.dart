import 'package:keel_core/modules/roadmap/model/task_claim.dart';
import 'package:keel_core/modules/roadmap/service/task_claims_store.dart';
import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:keel_ui/src/core/services/store_mirror_view_model.dart';

/// Mirror delgado de [TaskClaimsStore] (keel_core): toda la lógica real vive
/// ahí.
class TaskClaimsViewModel extends StoreMirrorViewModel<RoadmapClaimsState> {
  TaskClaimsViewModel() : super(TaskClaimsStore.instance);

  Future<void> get ready => TaskClaimsStore.instance.ready;

  /// Las tomas vivas de [projectPath]. Filtra por proyecto SIEMPRE: dos repos
  /// distintos con una tarea llamada igual no tienen nada que ver.
  List<TaskClaim> activeClaimsFor(String projectPath) =>
      TaskClaimsStore.instance.activeClaimsFor(projectPath);

  /// Quién tiene [taskPath] en [projectPath], o null si está libre.
  TaskClaim? claimOf(String projectPath, String taskPath) =>
      TaskClaimsStore.instance.claimOf(projectPath, taskPath);

  /// Toma la tarea. Devuelve null si quedó tomada, o el motivo si no.
  ({TaskClaim? claim, String? error}) claimTask({
    required String projectPath,
    required String projectName,
    required String taskPath,
    required String title,
    required String profileHandle,
    required String sessionId,
    required String sessionTitle,
  }) => TaskClaimsStore.instance.claimTask(
    projectPath: projectPath,
    projectName: projectName,
    taskPath: taskPath,
    title: title,
    profileHandle: profileHandle,
    sessionId: sessionId,
    sessionTitle: sessionTitle,
  );

  /// Suelta la tarea. Solo puede soltarla quien la tomó: si no, un agente
  /// podría destrabarle la tarea a otro que sigue trabajando.
  String? releaseTask({
    required String projectPath,
    required String taskPath,
    required String profileHandle,
  }) => TaskClaimsStore.instance.releaseTask(
    projectPath: projectPath,
    taskPath: taskPath,
    profileHandle: profileHandle,
  );

  /// Saca del registro lo que ya venció. Barato y sin efectos: se llama al
  /// listar, para que nadie vea como tomada una tarea que ya nadie tiene.
  void pruneExpired() => TaskClaimsStore.instance.pruneExpired();
}

mixin TaskClaimsService {
  static final ReactiveNotifier<TaskClaimsViewModel> instance =
      ReactiveNotifier<TaskClaimsViewModel>(() => TaskClaimsViewModel());
}
