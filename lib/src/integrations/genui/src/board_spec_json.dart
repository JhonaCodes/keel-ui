part of '../genui.dart';

/// El resultado de leer la especificación que mandó un agente.
typedef BoardSpec = ({Board? board, List<String> errors});

const _knownMethods = {
  'GET',
  'POST',
  'PUT',
  'PATCH',
  'DELETE',
  'HEAD',
  'OPTIONS',
};

/// Convierte lo que escribió un modelo en un [Board], o dice qué está mal.
///
/// Es LA frontera de este feature: nada de lo que escribe un agente entra al
/// modelo de datos sin pasar por acá. Y los mensajes son para el agente, que
/// es quien los va a leer y corregir, así que dicen qué falta y no
/// "argumento inválido".
///
/// La validación que más paga es la última: que toda `{{clave}}` que un paso
/// usa exista como campo del tablero o como captura de un paso ANTERIOR. Sin
/// eso, el tablero se guarda prolijo y explota recién cuando lo apretás.
BoardSpec parseBoardSpec(
  Map<String, dynamic> spec, {
  required String projectId,
  required String createdByProfileId,
  Board? existing,
  DateTime? now,
}) {
  final errors = <String>[];

  final name = (spec['name'] as String? ?? '').trim();
  if (name.isEmpty) errors.add('Falta "name": cómo se llama el tablero.');

  final fields = <BoardField>[];
  final fieldKeys = <String>{};
  for (final raw in spec['fields'] as List? ?? const []) {
    if (raw is! Map) {
      errors.add('Cada elemento de "fields" tiene que ser un objeto.');
      continue;
    }
    final field = raw.cast<String, dynamic>();
    final key = (field['key'] as String? ?? '').trim();
    final keyError = validateBoardFieldKey(key);
    if (keyError != null) {
      errors.add('Campo "$key": $keyError');
      continue;
    }
    if (!fieldKeys.add(key)) {
      errors.add('El campo "$key" está declarado dos veces.');
      continue;
    }

    final kind = BoardFieldKind.fromAlias(field['kind'] as String? ?? 'texto');
    final options = [
      for (final option in field['options'] as List? ?? const [])
        option.toString(),
    ];
    final secretName = (field['secret_name'] as String? ?? '').trim();

    if (kind == BoardFieldKind.opcion && options.isEmpty) {
      errors.add('El campo "$key" es de tipo opcion y no trae "options".');
      continue;
    }
    if (kind == BoardFieldKind.secreto && secretName.isEmpty) {
      errors.add(
        'El campo "$key" es de tipo secreto y no dice de qué secret sale '
        '("secret_name").',
      );
      continue;
    }

    fields.add(
      BoardField(
        key: key,
        label: (field['label'] as String? ?? key).trim(),
        kind: kind,
        defaultValue: field['default'] as String? ?? '',
        options: options,
        secretName: secretName,
        required: field['required'] as bool? ?? false,
        hint: (field['hint'] as String? ?? '').trim(),
      ),
    );
  }

  final actions = <BoardAction>[];
  final rawActions = spec['actions'] as List? ?? const [];
  if (rawActions.isEmpty) {
    errors.add('Falta "actions": un tablero sin botón no hace nada.');
  }

  for (final raw in rawActions) {
    if (raw is! Map) {
      errors.add('Cada elemento de "actions" tiene que ser un objeto.');
      continue;
    }
    final action = raw.cast<String, dynamic>();
    final label = (action['label'] as String? ?? '').trim();
    if (label.isEmpty) {
      errors.add('Una acción no dice qué texto lleva el botón ("label").');
      continue;
    }

    final rawSteps = action['steps'] as List? ?? const [];
    if (rawSteps.isEmpty) {
      errors.add('La acción "$label" no tiene pasos.');
      continue;
    }

    // Lo que hay disponible en cada punto: los campos, más lo que hayan
    // capturado los pasos de más arriba. Crece a medida que avanza.
    final available = {...fieldKeys};
    final steps = <BoardStep>[];
    var broken = false;

    for (var index = 0; index < rawSteps.length; index++) {
      final rawStep = rawSteps[index];
      if (rawStep is! Map) {
        errors.add('La acción "$label": el paso ${index + 1} no es un objeto.');
        broken = true;
        break;
      }
      final step = rawStep.cast<String, dynamic>();
      final where = 'La acción "$label", paso ${index + 1}';
      final kind = BoardStepKind.fromAlias(step['kind'] as String? ?? 'http');

      final captures = <StepCapture>[];
      for (final rawCapture in step['captures'] as List? ?? const []) {
        if (rawCapture is! Map) continue;
        final capture = rawCapture.cast<String, dynamic>();
        final as = (capture['as'] as String? ?? '').trim();
        final asError = validateBoardFieldKey(as);
        if (asError != null) {
          errors.add('$where: la captura "$as" $asError');
          broken = true;
          break;
        }
        if (fieldKeys.contains(as)) {
          errors.add(
            '$where: la captura "$as" pisa un campo del tablero. Elegí otro '
            'nombre.',
          );
          broken = true;
          break;
        }
        final from = CaptureFrom.fromAlias(capture['from'] as String? ?? '');
        final path = (capture['path'] as String? ?? '').trim();
        if (from != CaptureFrom.salida && path.isEmpty) {
          errors.add(
            '$where: la captura "$as" sale de ${from.alias} y no dice de '
            'dónde ("path").',
          );
          broken = true;
          break;
        }
        captures.add(StepCapture(as: as, from: from, path: path));
      }
      if (broken) break;

      final parsed = switch (kind) {
        BoardStepKind.http => _parseHttpStep(step, captures, where, errors),
        BoardStepKind.comando => _parseCommandStep(
          step,
          captures,
          where,
          errors,
        ),
      };
      if (parsed == null) {
        broken = true;
        break;
      }

      final unknown = _unknownKeys(parsed, available);
      if (unknown.isNotEmpty) {
        errors.add(
          '$where usa ${unknown.map((k) => '{{$k}}').join(', ')} y no existe: '
          'no es un campo del tablero ni lo captura un paso anterior.',
        );
        broken = true;
        break;
      }

      steps.add(parsed);
      available.addAll([for (final capture in captures) capture.as]);
    }

    if (broken) continue;
    actions.add(BoardAction(id: generateUuidV4(), label: label, steps: steps));
  }

  if (errors.isNotEmpty) return (board: null, errors: errors);

  final stamp = now ?? DateTime.now();
  return (
    board: Board(
      id: existing?.id ?? generateUuidV4(),
      projectId: projectId,
      name: name,
      note: (spec['note'] as String? ?? '').trim(),
      fields: fields,
      actions: actions,
      createdByProfileId: existing?.createdByProfileId ?? createdByProfileId,
      createdAt: existing?.createdAt ?? stamp,
      updatedAt: stamp,
    ),
    errors: const <String>[],
  );
}

BoardStep? _parseHttpStep(
  Map<String, dynamic> step,
  List<StepCapture> captures,
  String where,
  List<String> errors,
) {
  final url = (step['url'] as String? ?? '').trim();
  if (url.isEmpty) {
    errors.add('$where es HTTP y no trae "url".');
    return null;
  }
  final method = (step['method'] as String? ?? 'GET').trim().toUpperCase();
  if (!_knownMethods.contains(method)) {
    errors.add('$where usa el método "$method", que no existe.');
    return null;
  }
  return BoardStep(
    kind: BoardStepKind.http,
    method: method,
    url: url,
    headers: (step['headers'] as Map?)?.cast<String, String>() ?? const {},
    body: step['body'] as String? ?? '',
    captures: captures,
  );
}

BoardStep? _parseCommandStep(
  Map<String, dynamic> step,
  List<StepCapture> captures,
  String where,
  List<String> errors,
) {
  final command = (step['command'] as String? ?? '').trim();
  if (command.isEmpty) {
    errors.add('$where es un comando y no dice cuál ("command").');
    return null;
  }
  return BoardStep(
    kind: BoardStepKind.comando,
    command: command,
    args: [for (final arg in step['args'] as List? ?? const []) arg.toString()],
    captures: captures,
  );
}

/// Las claves que un paso usa y no están disponibles todavía.
List<String> _unknownKeys(BoardStep step, Set<String> available) {
  final used = <String>{
    ...templateKeysIn(step.url),
    ...templateKeysIn(step.body),
    ...templateKeysIn(step.command),
    for (final value in step.headers.values) ...templateKeysIn(value),
    for (final arg in step.args) ...templateKeysIn(arg),
  };
  return [
    for (final key in used)
      if (!available.contains(key)) key,
  ];
}
