part of '../genui.dart';

final RegExp _placeholder = RegExp(r'\{\{\s*([a-z][a-z0-9_]{0,31})\s*\}\}');

/// Las claves que un texto usa, sin repetir y en orden de aparición.
List<String> templateKeysIn(String text) {
  final seen = <String>{};
  for (final match in _placeholder.allMatches(text)) {
    seen.add(match.group(1)!);
  }
  return seen.toList();
}

/// Una plantilla que pide algo que nadie le dio.
///
/// Es un error con nombre y no un reemplazo silencioso a propósito: la
/// alternativa —mandar `{{campo}}` literal— llega a tu API como un pedido
/// raro y te hace buscar el problema del lado equivocado durante media hora.
class MissingTemplateKeys implements Exception {
  MissingTemplateKeys(this.keys);

  final List<String> keys;

  String get message => keys.length == 1
      ? 'Falta el valor de {{${keys.single}}}.'
      : 'Faltan los valores de ${keys.map((k) => '{{$k}}').join(', ')}.';

  @override
  String toString() => message;
}

/// Reemplaza cada `{{clave}}` de [text] por su valor.
///
/// Tira [MissingTemplateKeys] si falta alguna. No hace reemplazo recursivo:
/// un valor que contiene `{{otra}}` queda tal cual, porque una plantilla que
/// se expande sola es una que puede no terminar nunca.
String renderTemplate(String text, Map<String, String> values) {
  final missing = <String>[];
  final rendered = text.replaceAllMapped(_placeholder, (match) {
    final key = match.group(1)!;
    final value = values[key];
    if (value == null) {
      missing.add(key);
      return match.group(0)!;
    }
    return value;
  });

  if (missing.isNotEmpty) {
    throw MissingTemplateKeys(missing.toSet().toList());
  }
  return rendered;
}

/// Un valor de un JSON por ruta con puntos: `data.items.0.id`.
///
/// Devuelve null si el camino no existe, en vez de tirar: una captura que no
/// encontró nada tiene que poder decirlo sin voltear la corrida.
String? readJsonPath(Object? json, String path) {
  Object? current = json;
  for (final segment in path.split('.')) {
    if (segment.isEmpty) continue;
    switch (current) {
      case Map<String, dynamic> map:
        current = map[segment];
      case List list:
        final index = int.tryParse(segment);
        if (index == null || index < 0 || index >= list.length) return null;
        current = list[index];
      default:
        return null;
    }
  }
  return switch (current) {
    null => null,
    String value => value,
    _ => jsonEncode(current),
  };
}

/// El pedido HTTP de un paso, con las plantillas ya resueltas.
typedef StepRequest = ({
  String method,
  Uri uri,
  Map<String, String> headers,
  String body,
});

/// Arma el pedido de [step] con [values]. Puro: no sale a la red.
///
/// Los valores que van a la URL se codifican; los que van al cuerpo o a un
/// header, no. Es la diferencia entre un `&` que separa parámetros y un `&`
/// que es parte de un nombre.
StepRequest buildStepRequest(BoardStep step, Map<String, String> values) {
  final encoded = {
    for (final entry in values.entries)
      entry.key: Uri.encodeComponent(entry.value),
  };

  final url = renderTemplate(step.url, encoded);
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) {
    throw FormatException('La URL no se entiende: $url');
  }

  return (
    method: step.method.toUpperCase(),
    uri: uri,
    headers: {
      for (final entry in step.headers.entries)
        entry.key: renderTemplate(entry.value, values),
    },
    body: renderTemplate(step.body, values),
  );
}

/// El comando de un paso, con las plantillas resueltas.
typedef StepCommand = ({String command, List<String> args});

/// Arma el comando de [step]. Cada argumento se resuelve por separado y
/// **no se parte**: un valor con espacios sigue siendo un argumento, que es
/// justamente lo que pasar por una shell rompería.
StepCommand buildStepCommand(BoardStep step, Map<String, String> values) => (
  command: renderTemplate(step.command, values),
  args: [for (final arg in step.args) renderTemplate(arg, values)],
);
