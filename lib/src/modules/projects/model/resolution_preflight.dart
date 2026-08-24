import 'package:flutter/foundation.dart';

/// Deterministic context resolution performed before the first paid turn.
/// Both successful injections and missing requirements are persisted so the
/// workflow rail and map inspect the same evidence as the execution engine.
@immutable
class ResolutionPreflight {
  final bool performed;
  final List<String> injectedSkills;
  final List<String> injectedRules;
  final List<String> injectedKnowledge;
  final List<String> missingSkills;
  final List<String> missingRules;
  final List<String> missingKnowledge;
  final List<String> missingAgents;
  final List<String> missingSecrets;

  const ResolutionPreflight({
    this.performed = false,
    this.injectedSkills = const [],
    this.injectedRules = const [],
    this.injectedKnowledge = const [],
    this.missingSkills = const [],
    this.missingRules = const [],
    this.missingKnowledge = const [],
    this.missingAgents = const [],
    this.missingSecrets = const [],
  });

  bool get ready =>
      performed &&
      missingSkills.isEmpty &&
      missingRules.isEmpty &&
      missingKnowledge.isEmpty &&
      missingAgents.isEmpty &&
      missingSecrets.isEmpty;

  String get errorSummary => [
    if (missingSkills.isNotEmpty) 'skills: ${missingSkills.join(', ')}',
    if (missingRules.isNotEmpty) 'reglas: ${missingRules.join(', ')}',
    if (missingKnowledge.isNotEmpty) 'bases: ${missingKnowledge.join(', ')}',
    if (missingAgents.isNotEmpty) 'agentes: ${missingAgents.join(', ')}',
    if (missingSecrets.isNotEmpty) 'credenciales: ${missingSecrets.join(', ')}',
  ].join(' · ');

  Map<String, dynamic> toJson() => {
    'performed': performed,
    'injectedSkills': injectedSkills,
    'injectedRules': injectedRules,
    'injectedKnowledge': injectedKnowledge,
    'missingSkills': missingSkills,
    'missingRules': missingRules,
    'missingKnowledge': missingKnowledge,
    'missingAgents': missingAgents,
    'missingSecrets': missingSecrets,
  };

  factory ResolutionPreflight.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    List<String> strings(String key) =>
        (data[key] as List?)?.cast<String>() ?? const [];
    return ResolutionPreflight(
      performed: data['performed'] as bool? ?? false,
      injectedSkills: strings('injectedSkills'),
      injectedRules: strings('injectedRules'),
      injectedKnowledge: strings('injectedKnowledge'),
      missingSkills: strings('missingSkills'),
      missingRules: strings('missingRules'),
      missingKnowledge: strings('missingKnowledge'),
      missingAgents: strings('missingAgents'),
      missingSecrets: strings('missingSecrets'),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResolutionPreflight &&
          performed == other.performed &&
          listEquals(injectedSkills, other.injectedSkills) &&
          listEquals(injectedRules, other.injectedRules) &&
          listEquals(injectedKnowledge, other.injectedKnowledge) &&
          listEquals(missingSkills, other.missingSkills) &&
          listEquals(missingRules, other.missingRules) &&
          listEquals(missingKnowledge, other.missingKnowledge) &&
          listEquals(missingAgents, other.missingAgents) &&
          listEquals(missingSecrets, other.missingSecrets);

  @override
  int get hashCode => Object.hash(
    performed,
    Object.hashAll(injectedSkills),
    Object.hashAll(injectedRules),
    Object.hashAll(injectedKnowledge),
    Object.hashAll(missingSkills),
    Object.hashAll(missingRules),
    Object.hashAll(missingKnowledge),
    Object.hashAll(missingAgents),
    Object.hashAll(missingSecrets),
  );
}
