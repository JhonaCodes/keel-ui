part of '../shared.dart';

/// Las letras con marca, plegadas a la letra pelada.
///
/// Por tabla y no por lista de vocales castellanas: acá conviven el español y
/// el inglés —hasta las palabras que dispara el ciclo son de los dos idiomas—
/// y el inglés arrastra prestadas que la lista corta no tocaba: `façade`,
/// `rôle`, `naïve`, `São`. Peor todavía donde el ciclo reconoce un «seguí», que después
/// tira lo que no sea `a-z`: una marca sin plegar no quedaba igual, se
/// borraba, y `continûe` terminaba siendo `contine`.
const _foldedLetters = <String, String>{
  'a': 'àáâãäåāăą',
  'c': 'çćĉċč',
  'd': 'ďđ',
  'e': 'èéêëēĕėęě',
  'g': 'ĝğġģ',
  'i': 'ìíîïĩīĭįı',
  'l': 'ĺļľŀł',
  'n': 'ñńņň',
  'o': 'òóôõöøōŏő',
  'r': 'ŕŗř',
  's': 'śŝşš',
  't': 'ţťŧ',
  'u': 'ùúûüũūŭůűų',
  'w': 'ŵ',
  'y': 'ýÿŷ',
  'z': 'źżž',
};

/// Las que no son una letra con marca sino dos letras juntas.
const _foldedLigatures = <String, String>{'æ': 'ae', 'œ': 'oe', 'ß': 'ss'};

final Map<int, String> _folding = {
  for (final entry in _foldedLetters.entries)
    for (final rune in entry.value.runes) rune: entry.key,
  for (final entry in _foldedLigatures.entries)
    entry.key.runes.single: entry.value,
};

/// Lo que abre una frase y no cambia lo que dice. `¿` y `¡` están acá por el
/// español; las comillas, por los dos idiomas.
final _leadingMarks = RegExp('^[¿¡"\'«‹]+');

/// Lo que la cierra. Los corchetes y paréntesis NO entran: sacarle el
/// paréntesis a «(opcional) correr tests» deja el otro colgando.
final _trailingMarks = RegExp('[.,;:!?…"\'»›]+\$');

final _whitespace = RegExp(r'\s+');

/// Normaliza [text] para compararlo con tolerancia: minúsculas, sin marcas
/// diacríticas, espacios colapsados y sin la puntuación de los bordes.
///
/// Es la comparación del plan de una sesión. Exigir el texto EXACTO convertía
/// un retoque de redacción en un desmarque: replanificar reformulando un
/// punto ya hecho lo devolvía a pendiente y el ciclo volvía a trabajar lo
/// mismo. Con esto, dos textos que dicen lo mismo con otra mayúscula, otro
/// acento u otro punto final son el mismo punto.
///
/// El orden importa: primero se recorta y recién después se sacan las marcas
/// de los bordes. Al revés —que es como estaba— un texto que terminaba en
/// «deps. » se quedaba con el punto, porque el ancla `$` no llegaba a él por
/// culpa del espacio, y el retoque que este método promete tolerar no se
/// toleraba.
String normalizeForMatch(String text) {
  final folded = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    folded.write(_folding[rune] ?? String.fromCharCode(rune));
  }

  return folded
      .toString()
      .replaceAll(_whitespace, ' ')
      .trim()
      .replaceAll(_leadingMarks, '')
      .replaceAll(_trailingMarks, '')
      .trim();
}
