import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';

final RegExp _agentProfileNameFormat = RegExp(r'^[a-z0-9_-]{1,16}$');

/// The handle reserved for the built-in system assistant, seeded once at
/// startup. Rejected everywhere a handle is written — created, updated, or
/// declared mid-conversation by a station member — so nothing can shadow or
/// delete it by picking the same name.
const kKeelAiHandle = 'keelai';

/// Returns a human error message if [value] can't be used as an
/// [AgentProfile.name], or null if it's valid. Enforced format: lowercase,
/// no spaces, max 16 chars — this name doubles as the address used for
/// communication between agents.
String? validateAgentProfileName(String value) {
  if (value.isEmpty) return 'El nombre no puede estar vacío.';
  if (value.length > 16) return 'Máximo 16 caracteres.';
  if (value.contains(' ')) return 'No se permiten espacios.';
  if (value != value.toLowerCase()) return 'Usa solo minúsculas.';
  if (!_agentProfileNameFormat.hasMatch(value)) {
    return 'Solo letras minúsculas, números, "-" y "_".';
  }
  return null;
}

/// El miembro que le toca a un paso que pide [role].
///
/// Empareja primero por ROL —que es lo que un paso nombra a propósito, para
/// que el mismo workflow sirva en cualquier estación que tenga ese rol— y si
/// nadie lo tiene, por HANDLE. El handle es único en toda la app, así que un
/// paso que dice "auditor" y el agente `@auditor` son inequívocamente lo
/// mismo; sin esta segunda pasada, un workflow escrito con handles queda con
/// todos sus pasos huérfanos aunque la estación tenga a los nueve miembros.
AgentProfile? memberForRole(Iterable<AgentProfile> members, String role) {
  final wanted = role.trim().toLowerCase();
  if (wanted.isEmpty) return null;
  for (final member in members) {
    if (member.role.trim().toLowerCase() == wanted) return member;
  }
  for (final member in members) {
    if (member.name.trim().toLowerCase() == wanted) return member;
  }
  return null;
}

/// A reusable, registered agent identity: name, role, system prompt, and
/// saved skills travel with it wherever it's instantiated. Permissions
/// (e.g. full file system access) are NOT part of the profile — they're set
/// per placement/context when the profile is used to create a live agent.
class AgentProfile {
  final String id;
  final String name;
  final String role;
  final String systemPrompt;
  final List<String> skills;
  final List<String> rules;

  /// Names of registered executable tools this profile's agents can call as
  /// real MCP tools during their turns — see `user_tools_mcp_server.dart`.
  final List<String> tools;

  /// Names of registered external MCP servers (gmail, drive, …) this
  /// profile's agents get wired into their turns — see F5.
  final List<String> mcpServers;

  /// Guardarraíles que corren cuando actúa este perfil, por nombre. A
  /// diferencia de [rules], que son texto que el modelo puede desobedecer,
  /// un hook lo ejecuta el CLI y puede frenar lo que estaba por pasar.
  final List<String> hooks;

  /// Bases de saber que este perfil lleva consigo, por nombre — el caso
  /// ORÁCULO: un agente cuyo trabajo es contestar desde esa documentación,
  /// también en 1:1, fuera de toda estación. Es una excepción deliberada al
  /// aislamiento por estación: la base viaja con el perfil a donde vaya, así
  /// que se usa para el agente que ES de ese dominio, no como atajo para
  /// darle documentación a un especialista general.
  final List<String> knowledgeBaseNames;

  /// A "builder" profile: its 1:1 agents receive the same `keelai-actions`
  /// MCP that Keel AI has, so they can create skills/rules/tools/agents/
  /// workflows/stations themselves. Off by default — creation power is an
  /// explicit grant, never ambient.
  final bool canManageSystem;

  /// Which local CLI drives this profile's agents (claude by default).
  /// Codex agents don't receive tools/MCPs/effort — see the F6 doc.
  final AgentProvider provider;
  final String model;
  final String effort;
  final DateTime createdAt;

  /// The member that asked for this agent to exist, when it was not you.
  /// An agent that needs a specialist the station lacks does not get to spawn
  /// it in the background — it declares it, the app registers it here, and the
  /// map shows who brought it in. Null means you registered it yourself.
  final String? createdByProfileId;

  const AgentProfile({
    required this.id,
    required this.name,
    required this.role,
    required this.systemPrompt,
    required this.model,
    required this.effort,
    required this.createdAt,
    this.skills = const [],
    this.rules = const [],
    this.tools = const [],
    this.mcpServers = const [],
    this.hooks = const [],
    this.knowledgeBaseNames = const [],
    this.canManageSystem = false,
    this.provider = AgentProvider.claude,
    this.createdByProfileId,
  });

  AgentProfile copyWith({
    String? name,
    String? role,
    String? systemPrompt,
    List<String>? skills,
    List<String>? rules,
    List<String>? tools,
    List<String>? mcpServers,
    List<String>? hooks,
    List<String>? knowledgeBaseNames,
    bool? canManageSystem,
    AgentProvider? provider,
    String? model,
    String? effort,
  }) {
    return AgentProfile(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      skills: skills ?? this.skills,
      rules: rules ?? this.rules,
      tools: tools ?? this.tools,
      mcpServers: mcpServers ?? this.mcpServers,
      hooks: hooks ?? this.hooks,
      knowledgeBaseNames: knowledgeBaseNames ?? this.knowledgeBaseNames,
      canManageSystem: canManageSystem ?? this.canManageSystem,
      provider: provider ?? this.provider,
      model: model ?? this.model,
      effort: effort ?? this.effort,
      createdAt: createdAt,
      createdByProfileId: createdByProfileId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role,
    'systemPrompt': systemPrompt,
    'skills': skills,
    'rules': rules,
    'tools': tools,
    'mcpServers': mcpServers,
    'hooks': hooks,
    'knowledgeBaseNames': knowledgeBaseNames,
    'canManageSystem': canManageSystem,
    'provider': provider.alias,
    'model': model,
    'effort': effort,
    'createdAt': createdAt.toIso8601String(),
    'createdByProfileId': createdByProfileId,
  };

  factory AgentProfile.fromJson(Map<String, dynamic> json) {
    return AgentProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      role: json['role'] as String? ?? '',
      systemPrompt: json['systemPrompt'] as String? ?? '',
      skills: (json['skills'] as List?)?.cast<String>() ?? const [],
      rules: (json['rules'] as List?)?.cast<String>() ?? const [],
      tools: (json['tools'] as List?)?.cast<String>() ?? const [],
      mcpServers: (json['mcpServers'] as List?)?.cast<String>() ?? const [],
      hooks: (json['hooks'] as List?)?.cast<String>() ?? const [],
      knowledgeBaseNames:
          (json['knowledgeBaseNames'] as List?)?.cast<String>() ?? const [],
      canManageSystem: json['canManageSystem'] as bool? ?? false,
      provider: json['provider'] == null
          ? AgentProvider.claude
          : AgentProvider.fromAlias(json['provider'] as String),
      model: json['model'] as String,
      effort: json['effort'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      createdByProfileId: json['createdByProfileId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          role == other.role &&
          systemPrompt == other.systemPrompt &&
          listEquals(skills, other.skills) &&
          listEquals(rules, other.rules) &&
          listEquals(tools, other.tools) &&
          listEquals(mcpServers, other.mcpServers) &&
          listEquals(hooks, other.hooks) &&
          listEquals(knowledgeBaseNames, other.knowledgeBaseNames) &&
          canManageSystem == other.canManageSystem &&
          provider == other.provider &&
          model == other.model &&
          effort == other.effort &&
          createdAt == other.createdAt &&
          createdByProfileId == other.createdByProfileId;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    role,
    systemPrompt,
    Object.hashAll(skills),
    Object.hashAll(rules),
    Object.hashAll(tools),
    Object.hashAll(mcpServers),
    Object.hashAll(knowledgeBaseNames),
    canManageSystem,
    provider,
    model,
    effort,
    createdAt,
    createdByProfileId,
  );

  @override
  String toString() =>
      'AgentProfile(id: $id, name: $name, role: $role, '
      'systemPrompt: ${systemPrompt.length} chars, skills: $skills, '
      'rules: $rules, tools: $tools, mcpServers: $mcpServers, '
      'canManageSystem: $canManageSystem, provider: ${provider.alias}, '
      'model: $model, effort: $effort, createdAt: $createdAt)';
}

class AgentProfilesState {
  final List<AgentProfile> profiles;

  const AgentProfilesState({this.profiles = const []});

  AgentProfilesState copyWith({List<AgentProfile>? profiles}) {
    return AgentProfilesState(profiles: profiles ?? this.profiles);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentProfilesState &&
          runtimeType == other.runtimeType &&
          listEquals(profiles, other.profiles);

  @override
  int get hashCode => Object.hashAll(profiles);

  @override
  String toString() => 'AgentProfilesState(profiles: ${profiles.length})';
}
