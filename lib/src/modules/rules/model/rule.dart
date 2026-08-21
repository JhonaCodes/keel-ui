import 'package:flutter/foundation.dart';

/// Returns a human error message if [value] can't be used as a
/// [Rule.name], or null if it's valid.
String? validateRuleName(String value) {
  if (value.isEmpty) return 'El nombre no puede estar vacío.';
  if (value.length > 60) return 'Máximo 60 caracteres.';
  return null;
}

/// A registered, reusable constraint or convention. Its [content] is
/// injected verbatim into an agent's system prompt when that agent's
/// profile has this rule assigned — the selection is static (decided when
/// the profile is configured), never inferred by the model at runtime.
class Rule {
  final String id;
  final String name;
  final String content;
  final DateTime createdAt;

  const Rule({
    required this.id,
    required this.name,
    required this.content,
    required this.createdAt,
  });

  Rule copyWith({String? name, String? content}) {
    return Rule(
      id: id,
      name: name ?? this.name,
      content: content ?? this.content,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Rule.fromJson(Map<String, dynamic> json) {
    return Rule(
      id: json['id'] as String,
      name: json['name'] as String,
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Rule &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          content == other.content &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, name, content, createdAt);

  @override
  String toString() =>
      'Rule(id: $id, name: $name, content: ${content.length} chars, '
      'createdAt: $createdAt)';
}

class RulesState {
  final List<Rule> rules;

  const RulesState({this.rules = const []});

  RulesState copyWith({List<Rule>? rules}) {
    return RulesState(rules: rules ?? this.rules);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RulesState &&
          runtimeType == other.runtimeType &&
          listEquals(rules, other.rules);

  @override
  int get hashCode => Object.hashAll(rules);

  @override
  String toString() => 'RulesState(rules: ${rules.length})';
}
