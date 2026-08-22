import 'dart:async';

import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/requirements/model/internal_requirement.dart';
import 'package:keel_ui/src/modules/requirements/repository/requirements_repository.dart';
import 'package:keel_ui/src/shared/shared.dart';

class RequirementsViewModel extends ViewModel<RequirementsState> {
  RequirementsViewModel() : super(const RequirementsState());

  RequirementsRepository get _repository => RequirementsRepository();

  Future<void>? _ready;
  Future<void> get ready => _ready ??= _loadPersistedRequirements();

  @override
  void init() {
    if (_ready == null) updateSilently(const RequirementsState());
    unawaited(ready);
  }

  Future<void> _loadPersistedRequirements() async {
    try {
      final requirements = await _repository.load();
      updateState(data.copyWith(requirements: requirements));
    } catch (error) {
      Log.e('Failed to load persisted requirements', error: error);
    }
  }

  // ── lectura ─────────────────────────────────────────────────────────

  InternalRequirement? byId(String id) =>
      data.requirements.where((entry) => entry.id == id).firstOrNull;

  InternalRequirement? byCode(String code) => data.requirements
      .where((entry) => entry.code.toLowerCase() == code.toLowerCase())
      .firstOrNull;

  /// Los que abrió este proyecto.
  List<InternalRequirement> outgoingOf(String projectId) => data.requirements
      .where((entry) => entry.fromProjectId == projectId)
      .toList();

  /// Los que le llegaron.
  List<InternalRequirement> incomingOf(String projectId) => data.requirements
      .where((entry) => entry.toProjectId == projectId)
      .toList();

  /// Los que esperan que alguien haga algo.
  List<InternalRequirement> get pending =>
      data.requirements.where((entry) => entry.status.isOpen).toList();

  void select(String? id) {
    updateState(
      id == null
          ? data.copyWith(clearSelection: true)
          : data.copyWith(selectedId: id),
    );
  }

  // ── alta ────────────────────────────────────────────────────────────

  /// Abre un requerimiento de un proyecto hacia otro.
  ///
  /// [external] lo marca como del lado de un proyecto que el usuario no
  /// mantiene: se anota igual, porque perder el pedido no ayuda a nadie, pero
  /// nadie lo va a tomar automáticamente.
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
  }) {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      return (requirement: null, error: 'El requerimiento necesita un título.');
    }
    if (need.trim().isEmpty) {
      return (
        requirement: null,
        error: 'Escribí qué necesitás: sin eso el otro lado no puede evaluar.',
      );
    }
    if (fromProjectId == toProjectId) {
      return (
        requirement: null,
        error: 'Un proyecto no se pide cosas a sí mismo — eso es una sesión.',
      );
    }

    final now = DateTime.now();
    final requirement = InternalRequirement(
      id: generateUuidV4(),
      code: _nextCode(),
      title: cleanTitle,
      fromProjectId: fromProjectId,
      toProjectId: toProjectId,
      need: need.trim(),
      context: context.trim(),
      blocking: blocking,
      openedByHandle: openedByHandle,
      openedInSessionId: openedInSessionId,
      status: external ? RequirementStatus.externo : RequirementStatus.abierto,
      createdAt: now,
      updatedAt: now,
    );
    _replace([...data.requirements, requirement]);
    return (requirement: requirement, error: null);
  }

  /// `REQ-0001`, `REQ-0002`… Sale del máximo que ya existe y no del conteo:
  /// borrar uno del medio no puede hacer que el próximo repita un código.
  String _nextCode() {
    var top = 0;
    for (final requirement in data.requirements) {
      final digits = requirement.code.replaceAll(RegExp(r'[^0-9]'), '');
      final value = int.tryParse(digits) ?? 0;
      if (value > top) top = value;
    }
    return 'REQ-${(top + 1).toString().padLeft(4, '0')}';
  }

  // ── el lado del destino ─────────────────────────────────────────────

  /// Lo toma y lo pone en evaluación.
  String? take(String id, {required String handle, required String sessionId}) {
    final requirement = byId(id);
    if (requirement == null) return 'Ese requerimiento no existe.';
    if (requirement.status == RequirementStatus.externo) {
      return 'Ese requerimiento va a un proyecto que no mantenés: lo tenés '
          'que resolver vos por afuera.';
    }
    if (!requirement.status.waitsOnTarget) {
      return 'No está esperando al destino: está ${requirement.status.label.toLowerCase()}.';
    }
    _update(
      requirement.copyWith(
        status: RequirementStatus.tomado,
        takenByHandle: handle,
        takenInSessionId: sessionId,
      ),
    );
    return null;
  }

  /// Deja el dictamen: viable, bloqueado, no viable, o ya resuelto de otra
  /// forma. Pasa a "en curso" salvo que ya esté resuelto, que va derecho a
  /// pedir el cierre.
  String? recordVerdict(
    String id, {
    required RequirementVerdict verdict,
    required String handle,
  }) {
    final requirement = byId(id);
    if (requirement == null) return 'Ese requerimiento no existe.';
    if (!requirement.status.isOpen) {
      return 'Ese requerimiento ya está ${requirement.status.label.toLowerCase()}.';
    }
    final entry = RequirementEntry(
      id: generateUuidV4(),
      side: RequirementSide.destino,
      kind: RequirementEntryKind.evaluacion,
      text: verdict.reason,
      createdAt: DateTime.now(),
      authorHandle: handle,
    );
    _update(
      requirement.copyWith(
        verdict: verdict,
        status: verdict.kind == RequirementVerdictKind.yaResuelto
            ? RequirementStatus.respondido
            : RequirementStatus.enCurso,
        thread: [...requirement.thread, entry],
      ),
    );
    return null;
  }

  /// El destino pide que se cierre, con justificación.
  ///
  /// **No lo cierra.** Es la asimetría que sostiene todo esto: quien abrió es
  /// el único que sabe si lo que necesitaba está de verdad.
  String? requestClosure(
    String id, {
    required String justification,
    required String handle,
  }) {
    final requirement = byId(id);
    if (requirement == null) return 'Ese requerimiento no existe.';
    if (!requirement.status.isOpen) {
      return 'Ese requerimiento ya está ${requirement.status.label.toLowerCase()}.';
    }
    if (justification.trim().isEmpty) {
      return 'Pedir el cierre necesita una justificación clara: es lo único '
          'que el otro lado va a leer para decidir.';
    }
    final entry = RequirementEntry(
      id: generateUuidV4(),
      side: RequirementSide.destino,
      kind: RequirementEntryKind.cierre,
      text: justification.trim(),
      createdAt: DateTime.now(),
      authorHandle: handle,
    );
    _update(
      requirement.copyWith(
        status: RequirementStatus.respondido,
        thread: [...requirement.thread, entry],
      ),
    );
    return null;
  }

  // ── el lado del origen ──────────────────────────────────────────────

  /// Lo cierra. Solo el origen.
  String? close(String id, {String? handle, String? note}) {
    final requirement = byId(id);
    if (requirement == null) return 'Ese requerimiento no existe.';
    if (requirement.status == RequirementStatus.cerrado) {
      return 'Ya estaba cerrado.';
    }
    final thread = [...requirement.thread];
    if (note != null && note.trim().isNotEmpty) {
      thread.add(
        RequirementEntry(
          id: generateUuidV4(),
          side: handle == null
              ? RequirementSide.usuario
              : RequirementSide.origen,
          kind: RequirementEntryKind.cierre,
          text: note.trim(),
          createdAt: DateTime.now(),
          authorHandle: handle,
        ),
      );
    }
    _update(
      requirement.copyWith(status: RequirementStatus.cerrado, thread: thread),
    );
    return null;
  }

  /// Lo cancela. También del origen: es la otra cara de la misma potestad.
  String? cancel(String id, {String? handle, String? note}) {
    final requirement = byId(id);
    if (requirement == null) return 'Ese requerimiento no existe.';
    if (!requirement.status.isOpen) {
      return 'Ese requerimiento ya está ${requirement.status.label.toLowerCase()}.';
    }
    _update(requirement.copyWith(status: RequirementStatus.cancelado));
    if (note != null && note.trim().isNotEmpty) {
      reply(
        id,
        side: handle == null ? RequirementSide.usuario : RequirementSide.origen,
        kind: RequirementEntryKind.respuesta,
        text: note,
        handle: handle,
      );
    }
    return null;
  }

  /// Rechaza el pedido de cierre y lo devuelve a en curso, explicando.
  String? rejectClosure(String id, {required String reason, String? handle}) {
    final requirement = byId(id);
    if (requirement == null) return 'Ese requerimiento no existe.';
    if (requirement.status != RequirementStatus.respondido) {
      return 'Nadie pidió cerrar este requerimiento.';
    }
    if (reason.trim().isEmpty) {
      return 'Decí qué falta: rechazar sin explicar deja al otro lado '
          'adivinando.';
    }
    final entry = RequirementEntry(
      id: generateUuidV4(),
      side: handle == null ? RequirementSide.usuario : RequirementSide.origen,
      kind: RequirementEntryKind.correccion,
      text: reason.trim(),
      createdAt: DateTime.now(),
      authorHandle: handle,
    );
    _update(
      requirement.copyWith(
        status: RequirementStatus.enCurso,
        thread: [...requirement.thread, entry],
      ),
    );
    return null;
  }

  // ── el hilo, que es lo único compartido ─────────────────────────────

  String? reply(
    String id, {
    required RequirementSide side,
    required RequirementEntryKind kind,
    required String text,
    String? handle,
  }) {
    final requirement = byId(id);
    if (requirement == null) return 'Ese requerimiento no existe.';
    if (text.trim().isEmpty) return 'No hay nada escrito.';

    final entry = RequirementEntry(
      id: generateUuidV4(),
      side: side,
      kind: kind,
      text: text.trim(),
      createdAt: DateTime.now(),
      authorHandle: handle,
    );
    _update(requirement.copyWith(thread: [...requirement.thread, entry]));
    return null;
  }

  /// Mete un requerimiento entero como vino del respaldo.
  ///
  /// Si ese código ya existe, **no lo pisa**. Un requerimiento es una
  /// conversación viva: restaurar una foto vieja encima borraría todo lo que
  /// pasó desde que se hizo el respaldo, que es exactamente lo que uno NO
  /// quiere de un respaldo.
  bool importSnapshot(InternalRequirement requirement) {
    if (byCode(requirement.code) != null) return false;
    _replace([...data.requirements, requirement]);
    return true;
  }

  /// Marca los requerimientos de un proyecto que ya no existe.
  ///
  /// No se borran: son historia compartida, y el otro lado sigue teniendo
  /// derecho a verla. Lo que sí pasa es que no se pueden tomar más.
  void markProjectDeleted(String projectId) {
    final touched = data.requirements
        .map(
          (requirement) =>
              (requirement.fromProjectId == projectId ||
                      requirement.toProjectId == projectId) &&
                  requirement.status.isOpen
              ? requirement.copyWith(status: RequirementStatus.externo)
              : requirement,
        )
        .toList();
    _replace(touched);
  }

  // ── plomería ────────────────────────────────────────────────────────

  void _update(InternalRequirement requirement) {
    _replace([
      for (final entry in data.requirements)
        if (entry.id == requirement.id) requirement else entry,
    ]);
  }

  void _replace(List<InternalRequirement> requirements) {
    updateState(data.copyWith(requirements: requirements));
    unawaited(_repository.save(requirements));
  }
}

mixin RequirementsService {
  static final ReactiveNotifier<RequirementsViewModel> instance =
      ReactiveNotifier<RequirementsViewModel>(() => RequirementsViewModel());
}
