import 'package:flutter/foundation.dart';

/// Returns a human error message if [value] can't be used as a
/// [Skill.name], or null if it's valid.
String? validateSkillName(String value) {
  if (value.isEmpty) return 'El nombre no puede estar vacío.';
  if (value.length > 60) return 'Máximo 60 caracteres.';
  return null;
}

/// A registered, reusable instruction bundle. Its [content] is injected
/// verbatim into an agent's system prompt when that agent's profile has
/// this skill assigned — the selection is static (decided when the
/// profile is configured), never inferred by the model at runtime.
///
/// A skill marked [isGlobal] is injected into EVERY agent's prompt (1:1 and
/// station turns alike) without any assignment.
class Skill {
  final String id;
  final String name;
  final String content;
  final bool isGlobal;
  final DateTime createdAt;

  const Skill({
    required this.id,
    required this.name,
    required this.content,
    required this.createdAt,
    this.isGlobal = false,
  });

  Skill copyWith({String? name, String? content, bool? isGlobal}) {
    return Skill(
      id: id,
      name: name ?? this.name,
      content: content ?? this.content,
      isGlobal: isGlobal ?? this.isGlobal,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'content': content,
    'isGlobal': isGlobal,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      id: json['id'] as String,
      name: json['name'] as String,
      content: json['content'] as String? ?? '',
      isGlobal: json['isGlobal'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Skill &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          content == other.content &&
          isGlobal == other.isGlobal &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, name, content, isGlobal, createdAt);

  @override
  String toString() =>
      'Skill(id: $id, name: $name, content: ${content.length} chars, '
      'isGlobal: $isGlobal, createdAt: $createdAt)';
}

class SkillsState {
  final List<Skill> skills;

  const SkillsState({this.skills = const []});

  SkillsState copyWith({List<Skill>? skills}) {
    return SkillsState(skills: skills ?? this.skills);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkillsState &&
          runtimeType == other.runtimeType &&
          listEquals(skills, other.skills);

  @override
  int get hashCode => Object.hashAll(skills);

  @override
  String toString() => 'SkillsState(skills: ${skills.length})';
}
