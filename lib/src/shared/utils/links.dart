part of '../shared.dart';

/// Bloques de código, donde una URL es texto y no un enlace.
final _codeSpans = RegExp(r'```[\s\S]*?(?:```|$)|`[^`\n]*`');

/// Una URL suelta. El lookbehind evita volver a envolver lo que ya es enlace
/// —`[texto](url)` y `<url>`—, y los cierres quedan fuera del match para que
/// una URL entre paréntesis no se coma el paréntesis.
final _bareUrl = RegExp(r'(?<![(\[<])https?://[^\s<>`)\]]+');

/// Puntuación de la oración pegada al final de la URL: `…/pull/12.` termina
/// la frase, no forma parte del enlace.
final _trailingPunctuation = RegExp(r'[.,;:!?]+$');

/// Un pull request de GitHub, del que interesa el número.
final _pullRequestUrl = RegExp(
  r'https://github\.com/[\w.-]+/[\w.-]+/pull/(\d+)',
);

/// [markdown] con cada bloque o span de código reemplazado por espacios.
///
/// Para escanear prosa sin que el código opine: un `@handle` dentro de un
/// diff o de un ejemplo no es una mención, y hasta esto se trataba como una
/// — disparando turnos reales. Los offsets se conservan (mismo largo).
String stripCodeSpans(String markdown) {
  return markdown.replaceAllMapped(
    _codeSpans,
    (match) => ' ' * (match.end - match.start),
  );
}

/// Envuelve como enlace markdown las URLs sueltas de [markdown].
///
/// El renderer solo hace clickeable lo que ya viene con sintaxis de enlace, y
/// las URLs que importan llegan peladas: `gh pr create` imprime la del PR en
/// una línea, tal cual. Sin esto hay que copiarla a mano al navegador.
///
/// Lo que está dentro de un bloque de código se deja intacto: ahí una URL es
/// parte de un comando o de una salida, no algo para ir a visitar.
String linkifyBareUrls(String markdown) {
  final buffer = StringBuffer();
  var cursor = 0;

  void linkifyPlain(String plain) {
    var start = 0;
    for (final match in _bareUrl.allMatches(plain)) {
      final raw = match.group(0)!;
      final url = raw.replaceAll(_trailingPunctuation, '');
      buffer
        ..write(plain.substring(start, match.start))
        ..write('[$url]($url)')
        ..write(raw.substring(url.length));
      start = match.end;
    }
    buffer.write(plain.substring(start));
  }

  for (final code in _codeSpans.allMatches(markdown)) {
    linkifyPlain(markdown.substring(cursor, code.start));
    buffer.write(code.group(0));
    cursor = code.end;
  }
  linkifyPlain(markdown.substring(cursor));

  return buffer.toString();
}

/// El último pull request de GitHub nombrado en [text], o null.
///
/// El último y no el primero: si una sesión abrió el PR y después lo rehízo,
/// el vigente es el de más abajo en el hilo.
({int number, String url})? lastPullRequestIn(String text) {
  final matches = _pullRequestUrl.allMatches(text).toList();
  if (matches.isEmpty) return null;
  final last = matches.last;
  return (number: int.parse(last.group(1)!), url: last.group(0)!);
}
