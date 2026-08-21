import 'dart:async';

import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/repository/agent_profiles_repository.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/shared/shared.dart';

class AgentProfilesViewModel extends ViewModel<AgentProfilesState> {
  AgentProfilesViewModel() : super(const AgentProfilesState());

  AgentProfilesRepository get _repository => AgentProfilesRepository();

  /// Resolves once the persisted catalog has loaded into [data]. Callers
  /// that need to check "does X already exist" before [data] is populated
  /// (e.g. seeding a reserved profile at startup) must await this first —
  /// checking against an empty in-flight list would insert a duplicate the
  /// moment the real load lands.
  ///
  /// Memoized rather than a `late final` set once in [init]: a ViewModel
  /// touched before any [BuildContext] exists (e.g. by the startup seed in
  /// `main.dart`) gets `init()` called a second time the moment its first
  /// context-bearing subscriber mounts — `reactive_notifier`'s own
  /// `reinitializeWithContext()`. A `late final` assigned again there throws;
  /// this getter just returns the already-in-flight future instead.
  Future<void>? _ready;
  Future<void> get ready => _ready ??= _loadPersistedProfiles();

  @override
  void init() {
    // Only reset state on the FIRST init — a re-init triggered by the
    // context hand-off above must not wipe a catalog that already loaded.
    if (_ready == null) updateSilently(const AgentProfilesState());
    unawaited(ready);
  }

  Future<void> _loadPersistedProfiles() async {
    try {
      final profiles = await _repository.load();
      updateState(data.copyWith(profiles: profiles));
    } catch (error) {
      Log.e('Failed to load persisted agent profiles', error: error);
    }
  }

  /// Registers a new profile. Returns a user-facing error message on
  /// failure (invalid or duplicate name), or null on success.
  String? createProfile({
    required String name,
    required String role,
    required String systemPrompt,
    required List<String> skills,
    required List<String> rules,
    required String model,
    required String effort,
    List<String> tools = const [],
    List<String> mcpServers = const [],
    List<String> knowledgeBaseNames = const [],
    bool canManageSystem = false,
    AgentProvider provider = AgentProvider.claude,
    String? createdByProfileId,
  }) {
    final error = _validateName(name);
    if (error != null) return error;

    final profile = AgentProfile(
      id: generateUuidV4(),
      name: name,
      role: role.trim(),
      systemPrompt: systemPrompt.trim(),
      skills: skills,
      rules: rules,
      tools: tools,
      mcpServers: mcpServers,
      knowledgeBaseNames: knowledgeBaseNames,
      canManageSystem: canManageSystem,
      provider: provider,
      model: model,
      effort: effort,
      createdAt: DateTime.now(),
      createdByProfileId: createdByProfileId,
    );
    final profiles = [...data.profiles, profile];
    updateState(data.copyWith(profiles: profiles));
    unawaited(_repository.save(profiles));
    return null;
  }

  /// Updates an existing profile. Returns a user-facing error message on
  /// failure (invalid or duplicate name), or null on success.
  String? updateProfile(
    String id, {
    required String name,
    required String role,
    required String systemPrompt,
    required List<String> skills,
    required List<String> rules,
    required String model,
    required String effort,
    List<String>? tools,
    List<String>? mcpServers,
    List<String>? knowledgeBaseNames,
    bool? canManageSystem,
    AgentProvider? provider,
  }) {
    final error = _validateName(name, excludingId: id);
    if (error != null) return error;

    final profiles = data.profiles
        .map(
          (profile) => profile.id == id
              ? profile.copyWith(
                  name: name,
                  role: role.trim(),
                  systemPrompt: systemPrompt.trim(),
                  skills: skills,
                  rules: rules,
                  tools: tools,
                  mcpServers: mcpServers,
                  knowledgeBaseNames: knowledgeBaseNames,
                  canManageSystem: canManageSystem,
                  provider: provider,
                  model: model,
                  effort: effort,
                )
              : profile,
        )
        .toList();
    updateState(data.copyWith(profiles: profiles));
    unawaited(_repository.save(profiles));
    return null;
  }

  /// Whether Keel AI's reserved profile currently carries [serverName].
  bool keelAiUsesMcpServer(String serverName) {
    final keelAi = data.profiles
        .where((profile) => profile.name == kKeelAiHandle)
        .firstOrNull;
    return keelAi?.mcpServers.contains(serverName) ?? false;
  }

  /// Grants or revokes an external MCP for Keel AI's reserved profile.
  ///
  /// The reserved profile is hidden from the profiles screen because its
  /// systemPrompt is app-owned and re-synced on every launch, so an edit
  /// there would silently revert. Its INTEGRATIONS are not re-synced —
  /// only the prompt is (see `syncReservedProfilePrompt`) — so granting one
  /// here sticks. Without this the assistant could never use a registered
  /// MCP: no screen in the app reaches that profile.
  void setKeelAiMcpServer(String serverName, {required bool enabled}) {
    final index = data.profiles.indexWhere(
      (profile) => profile.name == kKeelAiHandle,
    );
    if (index == -1) return;

    final current = data.profiles[index].mcpServers;
    if (current.contains(serverName) == enabled) return;

    final servers = enabled
        ? [...current, serverName]
        : current.where((name) => name != serverName).toList();
    final profiles = [...data.profiles];
    profiles[index] = profiles[index].copyWith(mcpServers: servers);
    updateState(data.copyWith(profiles: profiles));
    unawaited(_repository.save(profiles));
  }

  /// Refuses to delete the reserved system-assistant profile — nothing in
  /// the UI offers this on purpose, but the check stays here too since
  /// [deleteProfile] is the actual point of no return.
  void deleteProfile(String id) {
    final target = data.profiles.where((p) => p.id == id).firstOrNull;
    if (target?.name == kKeelAiHandle) return;

    final profiles = data.profiles
        .where((profile) => profile.id != id)
        .toList();
    updateState(data.copyWith(profiles: profiles));
    unawaited(_repository.save(profiles));
  }

  /// Ensures [profile] exists, without going through [_validateName] — that
  /// validation rejects [kKeelAiHandle] precisely so nothing else can claim
  /// it, which would also block seeding it. Idempotent by name; callers must
  /// `await ready` first so this checks the real persisted catalog, not an
  /// empty in-flight list.
  Future<void> seedReservedProfile(AgentProfile profile) async {
    if (data.profiles.any((p) => p.name == profile.name)) return;
    final profiles = [...data.profiles, profile];
    updateState(data.copyWith(profiles: profiles));
    await _repository.save(profiles);
  }

  /// Keeps a reserved profile's `systemPrompt` in sync with the code on
  /// every app start — the seed only runs once, but a mechanism prompt
  /// (like Keel AI's action-block grammar) needs to reach the profile even
  /// after it already exists. Also bypasses [_validateName] like
  /// [seedReservedProfile]: it isn't renaming anything, so the reserved-name
  /// rejection doesn't apply, but the check has no exception for "updating
  /// its own current name" either. A no-op if the prompt already matches, so
  /// callers can call this unconditionally on every launch.
  Future<void> syncReservedProfilePrompt(String id, String systemPrompt) async {
    final index = data.profiles.indexWhere((profile) => profile.id == id);
    if (index == -1 || data.profiles[index].systemPrompt == systemPrompt) {
      return;
    }
    final profiles = [...data.profiles];
    profiles[index] = profiles[index].copyWith(systemPrompt: systemPrompt);
    updateState(data.copyWith(profiles: profiles));
    await _repository.save(profiles);
  }

  String? _validateName(String name, {String? excludingId}) {
    if (name == kKeelAiHandle) return 'Ese nombre está reservado.';

    final formatError = validateAgentProfileName(name);
    if (formatError != null) return formatError;

    final isTaken = data.profiles.any(
      (profile) => profile.name == name && profile.id != excludingId,
    );
    if (isTaken) return 'Ya existe un agente registrado con ese nombre.';
    return null;
  }
}

mixin AgentProfilesService {
  static final ReactiveNotifier<AgentProfilesViewModel> instance =
      ReactiveNotifier<AgentProfilesViewModel>(() => AgentProfilesViewModel());
}
