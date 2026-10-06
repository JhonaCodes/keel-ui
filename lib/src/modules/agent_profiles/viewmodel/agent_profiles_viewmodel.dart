import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_core/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_core/modules/agent_profiles/service/agent_profiles_store.dart';
import 'package:keel_core/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/core/services/store_mirror_view_model.dart';

export 'package:keel_core/modules/agent_profiles/model/agent_profile.dart'
    show AgentProfilesState;

/// Thin mirror over [AgentProfilesStore] (keel_core): the real catalog,
/// validation and hook-assignment logic lives there so a future headless
/// CLI can run it without Flutter.
class AgentProfilesViewModel extends StoreMirrorViewModel<AgentProfilesState> {
  AgentProfilesViewModel() : super(AgentProfilesStore.instance);

  Future<void> get ready => AgentProfilesStore.instance.ready;

  String? createProfile({
    required String name,
    required String role,
    required String systemPrompt,
    required List<String> skills,
    required List<String> rules,
    required String model,
    required String effort,
    List<String> hooks = const [],
    List<String> tools = const [],
    List<String> mcpServers = const [],
    List<String> knowledgeBaseNames = const [],
    bool canManageSystem = false,
    AgentProvider provider = AgentProvider.claude,
    String? createdByProfileId,
  }) => AgentProfilesStore.instance.createProfile(
    name: name,
    role: role,
    systemPrompt: systemPrompt,
    skills: skills,
    rules: rules,
    model: model,
    effort: effort,
    hooks: hooks,
    tools: tools,
    mcpServers: mcpServers,
    knowledgeBaseNames: knowledgeBaseNames,
    canManageSystem: canManageSystem,
    provider: provider,
    createdByProfileId: createdByProfileId,
  );

  String? updateProfile(
    String id, {
    required String name,
    required String role,
    required String systemPrompt,
    required List<String> skills,
    required List<String> rules,
    required String model,
    required String effort,
    List<String>? hooks,
    List<String>? tools,
    List<String>? mcpServers,
    List<String>? knowledgeBaseNames,
    bool? canManageSystem,
    AgentProvider? provider,
  }) => AgentProfilesStore.instance.updateProfile(
    id,
    name: name,
    role: role,
    systemPrompt: systemPrompt,
    skills: skills,
    rules: rules,
    model: model,
    effort: effort,
    hooks: hooks,
    tools: tools,
    mcpServers: mcpServers,
    knowledgeBaseNames: knowledgeBaseNames,
    canManageSystem: canManageSystem,
    provider: provider,
  );

  bool keelAiUsesMcpServer(String serverName) =>
      AgentProfilesStore.instance.keelAiUsesMcpServer(serverName);

  void setKeelAiMcpServer(String serverName, {required bool enabled}) =>
      AgentProfilesStore.instance.setKeelAiMcpServer(
        serverName,
        enabled: enabled,
      );

  void renameHook(String from, String to) =>
      AgentProfilesStore.instance.renameHook(from, to);

  int detachHook(String hookName) =>
      AgentProfilesStore.instance.detachHook(hookName);

  void deleteProfile(String id) =>
      AgentProfilesStore.instance.deleteProfile(id);

  Future<void> seedReservedProfile(AgentProfile profile) =>
      AgentProfilesStore.instance.seedReservedProfile(profile);

  Future<void> syncReservedProfilePrompt(String id, String systemPrompt) =>
      AgentProfilesStore.instance.syncReservedProfilePrompt(id, systemPrompt);
}

mixin AgentProfilesService {
  static final ReactiveNotifier<AgentProfilesViewModel> instance =
      ReactiveNotifier<AgentProfilesViewModel>(() => AgentProfilesViewModel());
}
