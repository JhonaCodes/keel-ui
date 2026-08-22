import 'dart:async';

import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/hooks/model/hook.dart';
import 'package:keel_ui/src/modules/hooks/model/hook_event.dart';
import 'package:keel_ui/src/modules/hooks/repository/hooks_repository.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/shared/shared.dart';

class HooksViewModel extends ViewModel<HooksState> {
  HooksViewModel() : super(const HooksState());

  HooksRepository get _repository => HooksRepository();

  /// Resuelve cuando el catálogo persistido ya cargó — quien lea [data]
  /// fuera de un widget (el armado del turno, las tools de Keel AI, el
  /// respaldo) tiene que esperarlo. Mismo patrón que las reglas.
  Future<void>? _ready;
  Future<void> get ready => _ready ??= _loadPersistedHooks();

  @override
  void init() {
    if (_ready == null) updateSilently(const HooksState());
    unawaited(ready);
  }

  Future<void> _loadPersistedHooks() async {
    try {
      final hooks = await _repository.load();
      updateState(data.copyWith(hooks: hooks));
    } catch (error) {
      Log.e('Failed to load persisted hooks', error: error);
    }
  }

  /// Los hooks con estos nombres, en orden de catálogo. Los que no resuelven
  /// se saltean: un perfil puede nombrar uno que se borró.
  List<Hook> hooksByNames(Iterable<String> names) =>
      data.hooks.where((hook) => names.contains(hook.name)).toList();

  Hook? hookByName(String name) =>
      data.hooks.where((hook) => hook.name == name).firstOrNull;

  /// Los que corren para todos sin que nadie se los asigne.
  List<Hook> get globalHooks =>
      data.hooks.where((hook) => hook.isGlobal).toList();

  String? createHook({
    required String name,
    required String description,
    required HookEvent event,
    required HookBody body,
    String matcher = '',
    int timeoutSeconds = kDefaultHookTimeoutSeconds,
    List<String> enforces = const [],
    bool isGlobal = false,
    bool enabled = true,
  }) {
    final error = _validate(
      name,
      body: body,
      timeoutSeconds: timeoutSeconds,
    );
    if (error != null) return error;

    final hook = Hook(
      id: generateUuidV4(),
      name: name,
      description: description.trim(),
      event: event,
      matcher: matcher.trim(),
      body: body,
      timeoutSeconds: timeoutSeconds,
      enforces: enforces,
      isGlobal: isGlobal,
      enabled: enabled,
      createdAt: DateTime.now(),
    );
    final hooks = [...data.hooks, hook];
    updateState(data.copyWith(hooks: hooks));
    unawaited(_repository.save(hooks));
    return null;
  }

  String? updateHook(
    String id, {
    required String name,
    required String description,
    required HookEvent event,
    required HookBody body,
    String matcher = '',
    int timeoutSeconds = kDefaultHookTimeoutSeconds,
    List<String>? enforces,
    bool? isGlobal,
    bool? enabled,
  }) {
    final error = _validate(
      name,
      body: body,
      timeoutSeconds: timeoutSeconds,
      excludingId: id,
    );
    if (error != null) return error;

    final previous = data.hooks.where((hook) => hook.id == id).firstOrNull;
    final hooks = data.hooks
        .map(
          (hook) => hook.id == id
              ? hook.copyWith(
                  name: name,
                  description: description.trim(),
                  event: event,
                  matcher: matcher.trim(),
                  body: body,
                  timeoutSeconds: timeoutSeconds,
                  enforces: enforces,
                  isGlobal: isGlobal,
                  enabled: enabled,
                )
              : hook,
        )
        .toList();
    updateState(data.copyWith(hooks: hooks));
    unawaited(_repository.save(hooks));

    // Renombrar es, para quien lo tiene asignado, lo mismo que borrarlo: la
    // asignación va por nombre. Se arrastra el cambio en vez de dejar la
    // referencia muerta.
    if (previous != null && previous.name != name) {
      AgentProfilesService.instance.notifier.renameHook(previous.name, name);
      ProjectsService.instance.notifier.renameHook(previous.name, name);
    }
    return null;
  }

  /// Prende o apaga un hook sin perderlo.
  ///
  /// Es la palanca de emergencia: un guardarraíl mal escrito puede trabar a
  /// todos los agentes, y apagarlo tiene que ser más barato que borrarlo.
  String? setEnabled(String id, bool enabled) {
    final exists = data.hooks.any((hook) => hook.id == id);
    if (!exists) return 'Ese hook ya no existe.';
    final hooks = data.hooks
        .map((hook) => hook.id == id ? hook.copyWith(enabled: enabled) : hook)
        .toList();
    updateState(data.copyWith(hooks: hooks));
    unawaited(_repository.save(hooks));
    return null;
  }

  /// Cuántos perfiles y proyectos tienen asignado [hookName]. Es lo que se
  /// le muestra al usuario ANTES de borrar, para que sepa qué está soltando.
  ({int profiles, int projects}) assignmentsOf(String hookName) {
    final profiles = AgentProfilesService.instance.notifier.data.profiles
        .where((profile) => profile.hooks.contains(hookName))
        .length;
    final projects = ProjectsService.instance.notifier.data.projects
        .where((project) => project.hookNames.contains(hookName))
        .length;
    return (profiles: profiles, projects: projects);
  }

  /// Borra el hook del catálogo Y de todo lo que lo tenía asignado.
  ///
  /// Acá el módulo se aparta a propósito de cómo se borra una regla, que
  /// deja el nombre colgado en perfiles y proyectos y se saltea en silencio
  /// al armar el turno. Para un guardarraíl eso no sirve: una asignación que
  /// apunta a un hook borrado hace creer que algo está protegido cuando ya
  /// no lo está. Borrar acá es borrar en todos lados.
  void deleteHook(String id) {
    final hook = data.hooks.where((entry) => entry.id == id).firstOrNull;
    if (hook == null) return;

    final hooks = data.hooks.where((entry) => entry.id != id).toList();
    updateState(data.copyWith(hooks: hooks));
    unawaited(_repository.save(hooks));

    AgentProfilesService.instance.notifier.detachHook(hook.name);
    ProjectsService.instance.notifier.detachHook(hook.name);
  }

  String? _validate(
    String name, {
    required HookBody body,
    required int timeoutSeconds,
    String? excludingId,
  }) {
    final formatError = validateHookName(name);
    if (formatError != null) return formatError;

    final isTaken = data.hooks.any(
      (hook) => hook.name == name && hook.id != excludingId,
    );
    if (isTaken) return 'Ya existe un hook con ese nombre.';

    final bodyError = switch (body) {
      HookCommand(:final command) when command.trim().isEmpty =>
        'El comando no puede estar vacío.',
      HookToolRef(:final toolName) when toolName.trim().isEmpty =>
        'Elegí qué tool ejecuta este hook.',
      _ => null,
    };
    if (bodyError != null) return bodyError;

    if (timeoutSeconds < 1 || timeoutSeconds > kMaxHookTimeoutSeconds) {
      return 'El timeout debe estar entre 1 y $kMaxHookTimeoutSeconds '
          'segundos.';
    }
    return null;
  }
}

mixin HooksService {
  static final ReactiveNotifier<HooksViewModel> instance =
      ReactiveNotifier<HooksViewModel>(() => HooksViewModel());
}
