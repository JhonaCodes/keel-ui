import 'package:keel_core/modules/requirements/model/internal_requirement.dart';
import 'package:keel_core/modules/requirements/service/requirements_store.dart';
import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:keel_ui/src/core/services/store_mirror_view_model.dart';

/// Mirror delgado de [RequirementsStore] (keel_core): toda la lógica real
/// vive ahí.
class RequirementsViewModel extends StoreMirrorViewModel<RequirementsState> {
  RequirementsViewModel() : super(RequirementsStore.instance);

  Future<void> get ready => RequirementsStore.instance.ready;

  // ── lectura ─────────────────────────────────────────────────────────

  InternalRequirement? byId(String id) => RequirementsStore.instance.byId(id);

  InternalRequirement? byCode(String code) =>
      RequirementsStore.instance.byCode(code);

  /// Los que abrió este proyecto.
  List<InternalRequirement> outgoingOf(String projectId) =>
      RequirementsStore.instance.outgoingOf(projectId);

  /// Los que le llegaron.
  List<InternalRequirement> incomingOf(String projectId) =>
      RequirementsStore.instance.incomingOf(projectId);

  /// Los que esperan que alguien haga algo.
  List<InternalRequirement> get pending => RequirementsStore.instance.pending;

  void select(String? id) => RequirementsStore.instance.select(id);

  // ── alta ────────────────────────────────────────────────────────────

  /// Abre un requerimiento de un proyecto hacia otro.
  ({InternalRequirement? requirement, String? error}) open({
    required String fromProjectId,
    required String toProjectId,
    required String title,
    required String need,
    required String context,
    required String openedByHandle,
    required String openedInSessionId,
    bool blocking = false,
    bool external = false,
  }) => RequirementsStore.instance.open(
    fromProjectId: fromProjectId,
    toProjectId: toProjectId,
    title: title,
    need: need,
    context: context,
    openedByHandle: openedByHandle,
    openedInSessionId: openedInSessionId,
    blocking: blocking,
    external: external,
  );

  // ── el lado del destino ─────────────────────────────────────────────

  /// Lo toma y lo pone en evaluación.
  String? take(
    String id, {
    required String handle,
    required String sessionId,
  }) =>
      RequirementsStore.instance.take(id, handle: handle, sessionId: sessionId);

  /// Deja el dictamen: viable, bloqueado, no viable, o ya resuelto de otra
  /// forma.
  String? recordVerdict(
    String id, {
    required RequirementVerdict verdict,
    required String handle,
  }) => RequirementsStore.instance.recordVerdict(
    id,
    verdict: verdict,
    handle: handle,
  );

  /// El destino pide que se cierre, con justificación.
  String? requestClosure(
    String id, {
    required String justification,
    required String handle,
  }) => RequirementsStore.instance.requestClosure(
    id,
    justification: justification,
    handle: handle,
  );

  // ── el lado del origen ──────────────────────────────────────────────

  /// Lo cierra. Solo el origen.
  String? close(String id, {String? handle, String? note}) =>
      RequirementsStore.instance.close(id, handle: handle, note: note);

  /// Lo cancela. También del origen: es la otra cara de la misma potestad.
  String? cancel(String id, {String? handle, String? note}) =>
      RequirementsStore.instance.cancel(id, handle: handle, note: note);

  /// Rechaza el pedido de cierre y lo devuelve a en curso, explicando.
  String? rejectClosure(String id, {required String reason, String? handle}) =>
      RequirementsStore.instance.rejectClosure(
        id,
        reason: reason,
        handle: handle,
      );

  // ── el hilo, que es lo único compartido ─────────────────────────────

  bool isThinking(String id) => RequirementsStore.instance.isThinking(id);

  void markThinking(String id, bool thinking) =>
      RequirementsStore.instance.markThinking(id, thinking);

  /// Anota en qué tarea del roadmap del destino terminó.
  String? linkTask(String id, {required String taskPath, String? handle}) =>
      RequirementsStore.instance.linkTask(
        id,
        taskPath: taskPath,
        handle: handle,
      );

  String? reply(
    String id, {
    required RequirementSide side,
    required RequirementEntryKind kind,
    required String text,
    String? handle,
  }) => RequirementsStore.instance.reply(
    id,
    side: side,
    kind: kind,
    text: text,
    handle: handle,
  );

  /// Mete un requerimiento entero como vino del respaldo.
  bool importSnapshot(InternalRequirement requirement) =>
      RequirementsStore.instance.importSnapshot(requirement);

  /// Marca los requerimientos de un proyecto que ya no existe.
  void markProjectDeleted(String projectId) =>
      RequirementsStore.instance.markProjectDeleted(projectId);
}

mixin RequirementsService {
  static final ReactiveNotifier<RequirementsViewModel> instance =
      ReactiveNotifier<RequirementsViewModel>(() => RequirementsViewModel());
}
