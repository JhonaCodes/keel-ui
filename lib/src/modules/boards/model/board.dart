import 'package:flutter/foundation.dart';
import 'package:keel_ui/l10n/generated/app_localizations.dart';

final RegExp _boardKeyFormat = RegExp(r'^[a-z][a-z0-9_]{0,31}$');

/// Devuelve un error legible si [value] no sirve como clave de campo, o null.
/// La clave es lo que se escribe `{{asi}}` en una acción, así que se
/// restringe a lo que se puede leer de un vistazo adentro de una URL.
String? validateBoardFieldKey(String value, [AppLocalizations? l10n]) {
  if (value.isEmpty) return l10n?.validationNameRequired ?? 'Name is required.';
  if (!_boardKeyFormat.hasMatch(value)) {
    return l10n?.validationBoardKey ??
        'Use lowercase letters, numbers, and "_", starting with a letter (max. 32).';
  }
  return null;
}

/// Qué clase de campo es, que decide con qué se dibuja y cómo se valida.
enum BoardFieldKind {
  texto('texto'),
  multilinea('multilinea'),
  numero('numero'),
  booleano('booleano'),
  opcion('opcion'),
  json('json'),

  /// Un valor que sale de un secret registrado y **no se muestra**. Existe
  /// para el caso obvio —el token del ambiente de pruebas— sin obligar a
  /// pegarlo cada vez ni a dejarlo escrito en el tablero.
  secreto('secreto');

  final String alias;
  const BoardFieldKind(this.alias);

  static BoardFieldKind fromAlias(String alias) {
    for (final kind in values) {
      if (kind.alias == alias) return kind;
    }
    return BoardFieldKind.texto;
  }
}

/// Un dato que ponés vos antes de disparar.
class BoardField {
  final String key;
  final String label;
  final BoardFieldKind kind;

  /// Con qué viene lleno. Es lo que hace que un tablero sirva la segunda
  /// vez: el caso normal ya está escrito y solo cambiás lo que cambia.
  final String defaultValue;

  /// Solo para [BoardFieldKind.opcion].
  final List<String> options;

  /// Solo para [BoardFieldKind.secreto]: el NOMBRE del secret registrado.
  final String secretName;

  final bool required;
  final String hint;

  const BoardField({
    required this.key,
    required this.label,
    this.kind = BoardFieldKind.texto,
    this.defaultValue = '',
    this.options = const [],
    this.secretName = '',
    this.required = false,
    this.hint = '',
  });

  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'kind': kind.alias,
    'defaultValue': defaultValue,
    'options': options,
    'secretName': secretName,
    'required': required,
    'hint': hint,
  };

  factory BoardField.fromJson(Map<String, dynamic> json) => BoardField(
    key: json['key'] as String,
    label: json['label'] as String? ?? json['key'] as String,
    kind: BoardFieldKind.fromAlias(json['kind'] as String? ?? 'texto'),
    defaultValue: json['defaultValue'] as String? ?? '',
    options: (json['options'] as List?)?.cast<String>() ?? const [],
    secretName: json['secretName'] as String? ?? '',
    required: json['required'] as bool? ?? false,
    hint: json['hint'] as String? ?? '',
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardField &&
          key == other.key &&
          label == other.label &&
          kind == other.kind &&
          defaultValue == other.defaultValue &&
          listEquals(options, other.options) &&
          secretName == other.secretName &&
          required == other.required &&
          hint == other.hint;

  @override
  int get hashCode => Object.hash(
    key,
    label,
    kind,
    defaultValue,
    Object.hashAll(options),
    secretName,
    required,
    hint,
  );
}

/// De dónde sale lo que un paso se guarda para el siguiente.
enum CaptureFrom {
  /// Lo que el comando escribió en su salida estándar, sin los espacios de
  /// los bordes. Es el caso de `gcloud auth print-access-token`.
  salida('salida'),

  /// Un valor del cuerpo JSON de la respuesta, por ruta con puntos
  /// (`data.id`, `items.0.name`).
  json('json'),

  /// Un header de la respuesta, por nombre.
  header('header');

  final String alias;
  const CaptureFrom(this.alias);

  static CaptureFrom fromAlias(String alias) {
    for (final from in values) {
      if (from.alias == alias) return from;
    }
    return CaptureFrom.salida;
  }
}

/// Lo que un paso se guarda para que lo use el siguiente.
class StepCapture {
  /// Con qué nombre queda disponible: `{{as}}`.
  final String as;
  final CaptureFrom from;

  /// La ruta o el nombre del header, según [from].
  final String path;

  const StepCapture({required this.as, required this.from, this.path = ''});

  Map<String, dynamic> toJson() => {'as': as, 'from': from.alias, 'path': path};

  factory StepCapture.fromJson(Map<String, dynamic> json) => StepCapture(
    as: json['as'] as String,
    from: CaptureFrom.fromAlias(json['from'] as String? ?? 'salida'),
    path: json['path'] as String? ?? '',
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StepCapture &&
          as == other.as &&
          from == other.from &&
          path == other.path;

  @override
  int get hashCode => Object.hash(as, from, path);
}

enum BoardStepKind {
  http('http'),
  comando('comando');

  final String alias;
  const BoardStepKind(this.alias);

  static BoardStepKind fromAlias(String alias) =>
      alias == 'comando' ? BoardStepKind.comando : BoardStepKind.http;
}

/// Un paso de una acción: un pedido HTTP o un comando.
class BoardStep {
  final BoardStepKind kind;

  /// http.
  final String method;
  final String url;
  final Map<String, String> headers;
  final String body;

  /// comando.
  final String command;
  final List<String> args;

  final List<StepCapture> captures;

  const BoardStep({
    required this.kind,
    this.method = 'GET',
    this.url = '',
    this.headers = const {},
    this.body = '',
    this.command = '',
    this.args = const [],
    this.captures = const [],
  });

  /// Cómo se resume en una línea, antes de correr.
  String get preview => switch (kind) {
    BoardStepKind.http => '$method $url',
    BoardStepKind.comando => '$command ${args.join(' ')}'.trim(),
  };

  Map<String, dynamic> toJson() => {
    'kind': kind.alias,
    'method': method,
    'url': url,
    'headers': headers,
    'body': body,
    'command': command,
    'args': args,
    'captures': [for (final capture in captures) capture.toJson()],
  };

  factory BoardStep.fromJson(Map<String, dynamic> json) => BoardStep(
    kind: BoardStepKind.fromAlias(json['kind'] as String? ?? 'http'),
    method: json['method'] as String? ?? 'GET',
    url: json['url'] as String? ?? '',
    headers: (json['headers'] as Map?)?.cast<String, String>() ?? const {},
    body: json['body'] as String? ?? '',
    command: json['command'] as String? ?? '',
    args: (json['args'] as List?)?.cast<String>() ?? const [],
    captures: [
      for (final capture in json['captures'] as List? ?? const [])
        StepCapture.fromJson((capture as Map).cast<String, dynamic>()),
    ],
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardStep &&
          kind == other.kind &&
          method == other.method &&
          url == other.url &&
          mapEquals(headers, other.headers) &&
          body == other.body &&
          command == other.command &&
          listEquals(args, other.args) &&
          listEquals(captures, other.captures);

  @override
  int get hashCode => Object.hash(
    kind,
    method,
    url,
    Object.hashAll(headers.entries.map((e) => Object.hash(e.key, e.value))),
    body,
    command,
    Object.hashAll(args),
    Object.hashAll(captures),
  );
}

/// Un botón del tablero, con lo que pasa cuando lo apretás.
class BoardAction {
  final String id;
  final String label;
  final List<BoardStep> steps;

  const BoardAction({
    required this.id,
    required this.label,
    this.steps = const [],
  });

  /// Si alguno de sus pasos corre un comando. Es lo que decide si hace falta
  /// confirmar la primera vez: un pedido HTTP va a un servidor; un comando
  /// corre en tu máquina.
  bool get runsCommands =>
      steps.any((step) => step.kind == BoardStepKind.comando);

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'steps': [for (final step in steps) step.toJson()],
  };

  factory BoardAction.fromJson(Map<String, dynamic> json) => BoardAction(
    id: json['id'] as String,
    label: json['label'] as String,
    steps: [
      for (final step in json['steps'] as List? ?? const [])
        BoardStep.fromJson((step as Map).cast<String, dynamic>()),
    ],
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardAction &&
          id == other.id &&
          label == other.label &&
          listEquals(steps, other.steps);

  @override
  int get hashCode => Object.hash(id, label, Object.hashAll(steps));
}

/// Un tablero: la UI chiquita para probar algo de tu propia app.
///
/// Pertenece a un proyecto porque prueba SU API. Un tablero suelto tendría
/// que decidir contra qué corre, y esa decisión ya la tomó el proyecto.
class Board {
  final String id;
  final String projectId;
  final String name;

  /// Qué prueba y contra qué. Es lo que uno quiere leer seis semanas después.
  final String note;

  final List<BoardField> fields;
  final List<BoardAction> actions;

  /// El perfil del agente que lo escribió, o vacío si lo hiciste a mano.
  final String createdByProfileId;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Board({
    required this.id,
    required this.projectId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.note = '',
    this.fields = const [],
    this.actions = const [],
    this.createdByProfileId = '',
  });

  Board copyWith({
    String? name,
    String? note,
    List<BoardField>? fields,
    List<BoardAction>? actions,
    DateTime? updatedAt,
  }) => Board(
    id: id,
    projectId: projectId,
    name: name ?? this.name,
    note: note ?? this.note,
    fields: fields ?? this.fields,
    actions: actions ?? this.actions,
    createdByProfileId: createdByProfileId,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'name': name,
    'note': note,
    'fields': [for (final field in fields) field.toJson()],
    'actions': [for (final action in actions) action.toJson()],
    'createdByProfileId': createdByProfileId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Board.fromJson(Map<String, dynamic> json) => Board(
    id: json['id'] as String,
    projectId: json['projectId'] as String? ?? '',
    name: json['name'] as String,
    note: json['note'] as String? ?? '',
    fields: [
      for (final field in json['fields'] as List? ?? const [])
        BoardField.fromJson((field as Map).cast<String, dynamic>()),
    ],
    actions: [
      for (final action in json['actions'] as List? ?? const [])
        BoardAction.fromJson((action as Map).cast<String, dynamic>()),
    ],
    createdByProfileId: json['createdByProfileId'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(
      json['updatedAt'] as String? ?? json['createdAt'] as String,
    ),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Board &&
          id == other.id &&
          projectId == other.projectId &&
          name == other.name &&
          note == other.note &&
          listEquals(fields, other.fields) &&
          listEquals(actions, other.actions) &&
          createdByProfileId == other.createdByProfileId &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    name,
    note,
    Object.hashAll(fields),
    Object.hashAll(actions),
    createdByProfileId,
    updatedAt,
  );
}
