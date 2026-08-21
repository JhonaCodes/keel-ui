import 'package:flutter/foundation.dart';

final RegExp _secretNameFormat = RegExp(r'^[A-Z][A-Z0-9_]{0,63}$');

/// Returns a human error message if [value] can't be used as a
/// [Secret.name], or null if it's valid. The name doubles as the
/// environment-variable key the value is injected under, so it follows env
/// var conventions strictly.
String? validateSecretName(String value) {
  if (value.isEmpty) return 'El nombre no puede estar vacío.';
  if (!_secretNameFormat.hasMatch(value)) {
    return 'Formato de variable de entorno: MAYÚSCULAS, números y "_", '
        'empezando por letra (máx. 64).';
  }
  return null;
}

/// A named credential/environment value. The VALUE never reaches an LLM:
/// it is injected as an environment variable ONLY into deterministic
/// processes (tool scripts, external MCP servers), never into an agent's
/// CLI environment or any prompt, and the UI always renders it masked.
///
/// A secret can exist WITHOUT a value ([isPending]): Keel AI may request
/// that a key exist (`request_secret`), but only the user can fill the
/// value, from the Secrets screen.
class Secret {
  final String id;
  final String name;
  final String description;
  final String value;
  final DateTime createdAt;

  /// Set when an agent requested this secret's existence — visible in the
  /// UI so the user knows who asked and why (the why lives in
  /// [description]).
  final String? requestedByProfileId;

  const Secret({
    required this.id,
    required this.name,
    required this.description,
    required this.value,
    required this.createdAt,
    this.requestedByProfileId,
  });

  bool get isPending => value.isEmpty;

  Secret copyWith({String? name, String? description, String? value}) {
    return Secret(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      value: value ?? this.value,
      createdAt: createdAt,
      requestedByProfileId: requestedByProfileId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'value': value,
    'createdAt': createdAt.toIso8601String(),
    'requestedByProfileId': requestedByProfileId,
  };

  factory Secret.fromJson(Map<String, dynamic> json) {
    return Secret(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      value: json['value'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      requestedByProfileId: json['requestedByProfileId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Secret &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          value == other.value &&
          createdAt == other.createdAt &&
          requestedByProfileId == other.requestedByProfileId;

  @override
  int get hashCode =>
      Object.hash(id, name, description, value, createdAt, requestedByProfileId);

  // The value NEVER appears in logs — toString reports only whether one is
  // set.
  @override
  String toString() =>
      'Secret(id: $id, name: $name, isPending: $isPending, '
      'createdAt: $createdAt)';
}

class SecretsState {
  final List<Secret> secrets;

  const SecretsState({this.secrets = const []});

  SecretsState copyWith({List<Secret>? secrets}) {
    return SecretsState(secrets: secrets ?? this.secrets);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecretsState &&
          runtimeType == other.runtimeType &&
          listEquals(secrets, other.secrets);

  @override
  int get hashCode => Object.hashAll(secrets);

  @override
  String toString() => 'SecretsState(secrets: ${secrets.length})';
}
