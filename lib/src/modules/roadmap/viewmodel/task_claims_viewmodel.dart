import 'dart:async';

import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/roadmap/model/task_claim.dart';
import 'package:keel_ui/src/modules/roadmap/repository/task_claims_repository.dart';

/// Quién tiene tomada cada tarea del roadmap, ahora.
///
/// Es la única pieza del sistema de tareas que NO vive en el repo, y está acá
/// por una sola razón: tomar una tarea tiene que ser atómico. Entre que un
/// agente lee "libre" y escribe "mía", otro no puede colarse — y un archivo
/// en git no da esa garantía: dos agentes leen "libre" a la vez y los dos
/// creen que ganaron.
class TaskClaimsViewModel extends ViewModel<RoadmapClaimsState> {
  TaskClaimsViewModel() : super(const RoadmapClaimsState());

  TaskClaimsRepository get _repository => TaskClaimsRepository();

  Future<void>? _ready;
  Future<void> get ready => _ready ??= _loadPersistedClaims();

  @override
  void init() {
    if (_ready == null) updateSilently(const RoadmapClaimsState());
    unawaited(ready);
  }

  Future<void> _loadPersistedClaims() async {
    try {
      final claims = await _repository.load();
      // Al arrancar se descarta lo vencido de una: son tomas de agentes que
      // murieron con la app cerrada.
      final now = DateTime.now();
      updateState(
        data.copyWith(
          claims: claims.where((claim) => !claim.isExpiredAt(now)).toList(),
        ),
      );
    } catch (error) {
      Log.e('Failed to load persisted task claims', error: error);
    }
  }

  /// Las tomas vivas de [projectPath]. Filtra por proyecto SIEMPRE: dos repos
  /// distintos con una tarea llamada igual no tienen nada que ver.
  List<TaskClaim> activeClaimsFor(String projectPath) {
    final now = DateTime.now();
    final root = _normalize(projectPath);
    return data.claims
        .where(
          (claim) =>
              _normalize(claim.projectPath) == root && !claim.isExpiredAt(now),
        )
        .toList();
  }

  /// Quién tiene [taskPath] en [projectPath], o null si está libre.
  TaskClaim? claimOf(String projectPath, String taskPath) {
    final id = claimIdFor(projectPath, taskPath);
    final now = DateTime.now();
    return data.claims
        .where((claim) => claim.id == id && !claim.isExpiredAt(now))
        .firstOrNull;
  }

  /// Toma la tarea. Devuelve null si quedó tomada, o el motivo si no.
  ///
  /// **Es síncrona a propósito, y de eso depende todo.** Dart corre un
  /// isolate por vez, así que entre la lectura y la escritura de acá no puede
  /// meterse otra toma: no hay `await` en el medio donde ceder el turno. Si
  /// esto fuera `async` y leyera de la base, dos agentes podrían leer "libre"
  /// simultáneamente y ganar los dos. La persistencia va después, sin
  /// esperarla, porque la decisión ya se tomó en memoria.
  ({TaskClaim? claim, String? error}) claimTask({
    required String projectPath,
    required String projectName,
    required String taskPath,
    required String title,
    required String profileHandle,
    required String stationName,
  }) {
    final now = DateTime.now();
    final id = claimIdFor(projectPath, taskPath);
    final existing = data.claims.where((claim) => claim.id == id).firstOrNull;

    if (existing != null && !existing.isExpiredAt(now)) {
      // Volver a tomar lo propio no es un choque: es renovar. Un turno largo
      // que sigue trabajando no tiene que perder su tarea por el reloj.
      if (existing.profileHandle == profileHandle &&
          existing.stationName == stationName) {
        final renewed = existing.renewedAt(now);
        _replace(id, renewed);
        return (claim: renewed, error: null);
      }
      final resta = existing.expiresAt.difference(now).inMinutes;
      return (
        claim: null,
        error:
            'La tiene ${existing.profileHandle} desde ${existing.stationName}. '
            'Se libera sola en $resta min si no la renueva. Tomá la siguiente.',
      );
    }

    final claim = TaskClaim(
      projectPath: projectPath,
      projectName: projectName,
      taskPath: taskPath,
      title: title,
      profileHandle: profileHandle,
      stationName: stationName,
      claimedAt: now,
      expiresAt: now.add(kClaimTtl),
    );
    _replace(id, claim);
    return (claim: claim, error: null);
  }

  /// Suelta la tarea. Solo puede soltarla quien la tomó: si no, un agente
  /// podría destrabarle la tarea a otro que sigue trabajando.
  String? releaseTask({
    required String projectPath,
    required String taskPath,
    required String profileHandle,
  }) {
    final id = claimIdFor(projectPath, taskPath);
    final existing = data.claims.where((claim) => claim.id == id).firstOrNull;
    if (existing == null) return 'Esa tarea no estaba tomada.';
    if (existing.profileHandle != profileHandle) {
      return 'La tiene ${existing.profileHandle}, no vos. Se libera sola '
          'cuando venza.';
    }

    final claims = data.claims.where((claim) => claim.id != id).toList();
    updateState(data.copyWith(claims: claims));
    unawaited(_repository.save(claims));
    return null;
  }

  /// Saca del registro lo que ya venció. Barato y sin efectos: se llama al
  /// listar, para que nadie vea como tomada una tarea que ya nadie tiene.
  void pruneExpired() {
    final now = DateTime.now();
    final vivos = data.claims
        .where((claim) => !claim.isExpiredAt(now))
        .toList();
    if (vivos.length == data.claims.length) return;
    updateState(data.copyWith(claims: vivos));
    unawaited(_repository.save(vivos));
  }

  void _replace(String id, TaskClaim claim) {
    final claims = [
      ...data.claims.where((entry) => entry.id != id),
      claim,
    ];
    updateState(data.copyWith(claims: claims));
    unawaited(_repository.save(claims));
  }

  static String _normalize(String path) {
    final trimmed = path.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}

mixin TaskClaimsService {
  static final ReactiveNotifier<TaskClaimsViewModel> instance =
      ReactiveNotifier<TaskClaimsViewModel>(() => TaskClaimsViewModel());
}
