import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/modules/hooks/model/hook_event.dart';

/// Cuánto puede tardar un hook antes de que lo maten.
///
/// Mucho más corto que el de una tool (600 s) y a propósito: un
/// `PreToolUse` corre ANTES DE CADA herramienta, así que su duración se
/// paga en cada paso del agente. Un guardarraíl que tarda medio minuto no
/// es un guardarraíl, es un freno de mano.
const kDefaultHookTimeoutSeconds = 10;
const kMaxHookTimeoutSeconds = 120;

final RegExp _hookNameFormat = RegExp(r'^[a-z0-9_-]{1,40}$');

/// El nombre es también el del script que se le entrega al CLI, así que no
/// admite espacios ni separadores de ruta.
String? validateHookName(String value) {
  if (value.isEmpty) return 'El nombre no puede estar vacío.';
  if (value.length > 40) return 'Máximo 40 caracteres.';
  if (value.contains(' ')) return 'No se permiten espacios.';
  if (value != value.toLowerCase()) return 'Usá solo minúsculas.';
  if (!_hookNameFormat.hasMatch(value)) {
    return 'Solo letras minúsculas, números, "-" y "_".';
  }
  return null;
}

/// Qué ejecuta un hook cuando su evento ocurre.
sealed class HookBody {
  const HookBody();

  Map<String, dynamic> toJson();

  static HookBody fromJson(Map<String, dynamic> json) {
    return switch (json['kind'] as String? ?? 'command') {
      'tool' => HookToolRef(json['toolName'] as String? ?? ''),
      _ => HookCommand(json['command'] as String? ?? ''),
    };
  }
}

/// Un comando de shell tal cual, como en la configuración nativa de los
/// CLIs: `./scripts/test.sh`, o un `jq` inline de una línea.
class HookCommand extends HookBody {
  final String command;

  const HookCommand(this.command);

  @override
  Map<String, dynamic> toJson() => {'kind': 'command', 'command': command};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HookCommand &&
          runtimeType == other.runtimeType &&
          command == other.command;

  @override
  int get hashCode => command.hashCode;

  @override
  String toString() => 'HookCommand($command)';
}

/// Una tool ya registrada, por nombre.
///
/// Es lo que permite escribir el cuerpo del hook DENTRO de la app —con su
/// runtime y sus secrets— en vez de dejarlo en un script suelto en el
/// disco. Además así viaja en el respaldo: un hook que apunta a
/// `./scripts/gate.sh` se restaura en otra máquina apuntando a un archivo
/// que allá no existe.
class HookToolRef extends HookBody {
  final String toolName;

  const HookToolRef(this.toolName);

  @override
  Map<String, dynamic> toJson() => {'kind': 'tool', 'toolName': toolName};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HookToolRef &&
          runtimeType == other.runtimeType &&
          toolName == other.toolName;

  @override
  int get hashCode => toolName.hashCode;

  @override
  String toString() => 'HookToolRef($toolName)';
}

/// Un guardarraíl que corre FUERA del modelo.
///
/// A diferencia de una regla —que es texto en el system prompt y que el
/// modelo puede desobedecer— un hook es un comando que ejecuta el CLI
/// cuando ocurre [event]. No pasa por el modelo, no se puede ignorar, y
/// según el evento puede frenar lo que estaba por pasar.
///
/// La regla dice el porqué; el hook garantiza el qué. Por eso [enforces]
/// existe: deja anotado qué regla hace cumplir este hook, y la pantalla de
/// reglas puede mostrar cuáles están garantizadas y cuáles solo pedidas.
class Hook {
  final String id;
  final String name;

  /// Qué hace y cuándo conviene. Es para vos, no para el modelo: el modelo
  /// nunca ve un hook, solo su efecto.
  final String description;

  final HookEvent event;

  /// Qué acota el hook dentro del evento — el nombre de la herramienta en
  /// `PreToolUse`, el origen en `SessionStart`. Vacío = todo.
  final String matcher;

  final HookBody body;
  final int timeoutSeconds;

  /// Nombres de reglas que este hook hace cumplir. Solo documentación: una
  /// regla que ya no existe se ignora, como cualquier referencia por nombre.
  final List<String> enforces;

  /// Un hook global corre para TODOS los agentes, sin que nadie se lo
  /// asigne — igual que una skill global. Es lo que se usa para un
  /// guardarraíl que no debería depender de acordarse de ponerlo.
  final bool isGlobal;

  /// Un hook apagado no se escribe en la configuración que recibe el CLI.
  /// Existe para poder frenar un guardarraíl sin perderlo.
  final bool enabled;

  final DateTime createdAt;

  const Hook({
    required this.id,
    required this.name,
    required this.description,
    required this.event,
    required this.body,
    required this.createdAt,
    this.matcher = '',
    this.timeoutSeconds = kDefaultHookTimeoutSeconds,
    this.enforces = const [],
    this.isGlobal = false,
    this.enabled = true,
  });

  /// El archivo que se le entrega al CLI para este hook.
  String get scriptFileName => '$name.sh';

  Hook copyWith({
    String? name,
    String? description,
    HookEvent? event,
    String? matcher,
    HookBody? body,
    int? timeoutSeconds,
    List<String>? enforces,
    bool? isGlobal,
    bool? enabled,
  }) {
    return Hook(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      event: event ?? this.event,
      matcher: matcher ?? this.matcher,
      body: body ?? this.body,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      enforces: enforces ?? this.enforces,
      isGlobal: isGlobal ?? this.isGlobal,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'event': event.alias,
    'matcher': matcher,
    'body': body.toJson(),
    'timeoutSeconds': timeoutSeconds,
    'enforces': enforces,
    'isGlobal': isGlobal,
    'enabled': enabled,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Hook.fromJson(Map<String, dynamic> json) {
    return Hook(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      event: HookEvent.fromAlias(json['event'] as String),
      matcher: json['matcher'] as String? ?? '',
      body: HookBody.fromJson(
        (json['body'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      timeoutSeconds:
          json['timeoutSeconds'] as int? ?? kDefaultHookTimeoutSeconds,
      enforces: (json['enforces'] as List?)?.cast<String>() ?? const [],
      isGlobal: json['isGlobal'] as bool? ?? false,
      enabled: json['enabled'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Hook &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          event == other.event &&
          matcher == other.matcher &&
          body == other.body &&
          timeoutSeconds == other.timeoutSeconds &&
          isGlobal == other.isGlobal &&
          enabled == other.enabled &&
          listEquals(enforces, other.enforces);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    event,
    matcher,
    body,
    timeoutSeconds,
    isGlobal,
    enabled,
    Object.hashAll(enforces),
  );

  @override
  String toString() =>
      'Hook(name: $name, event: ${event.alias}, enabled: $enabled)';
}

class HooksState {
  final List<Hook> hooks;

  const HooksState({this.hooks = const []});

  HooksState copyWith({List<Hook>? hooks}) =>
      HooksState(hooks: hooks ?? this.hooks);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HooksState &&
          runtimeType == other.runtimeType &&
          listEquals(hooks, other.hooks);

  @override
  int get hashCode => Object.hashAll(hooks);

  @override
  String toString() => 'HooksState(hooks: ${hooks.length})';
}
