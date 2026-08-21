import 'package:flutter/foundation.dart';

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
    this.createdByProfileId,
  });

  AgentProfile copyWith({
    String? name,
    String? role,
    String? systemPrompt,
    List<String>? skills,
    List<String>? rules,
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
    model,
    effort,
    createdAt,
    createdByProfileId,
  );

  @override
  String toString() =>
      'AgentProfile(id: $id, name: $name, role: $role, '
      'systemPrompt: ${systemPrompt.length} chars, skills: $skills, '
      'rules: $rules, model: $model, effort: $effort, createdAt: $createdAt)';
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
