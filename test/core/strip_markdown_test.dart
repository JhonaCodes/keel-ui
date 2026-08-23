import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/claude_stream_events.dart';

void main() {
  group('sacarle el markdown a un texto', () {
    test('un encabezado se lee sin sus almohadillas', () {
      expect(stripMarkdown('## Cierre del Paso 3'), 'Cierre del Paso 3');
      expect(stripMarkdown('###### chiquito'), 'chiquito');
    });

    test('la negrita y el código se van, el texto queda', () {
      expect(
        stripMarkdown('**Dejé listo:** el glosario en `GLOSARIO.md`'),
        'Dejé listo: el glosario en GLOSARIO.md',
      );
    });

    test('las viñetas pierden la marca, no el punto', () {
      expect(
        stripMarkdown('- uno\n* dos\n1. tres'),
        'uno\ndos\ntres',
      );
    });

    test('un enlace se lee por su texto', () {
      expect(
        stripMarkdown('mirá [el PR](https://github.com/x/y/pull/3)'),
        'mirá el PR',
      );
    });

    test('una regla horizontal no deja rastro', () {
      // Es la que aparecía como `---` colgando al principio del cuadro.
      expect(stripMarkdown('---\n## Análisis').trim(), 'Análisis');
    });

    test('un asterisco suelto no se toca: no es énfasis', () {
      expect(stripMarkdown('2 * 3 = 6'), '2 * 3 = 6');
    });

    test('la primera frase sale limpia y recortada', () {
      final excerpt = firstSentenceOf(
        '## Cierre del Paso 3\n\n**Dejé listo:** el glosario base.\n'
        'Y algo más que no entra.',
      );
      expect(excerpt, 'Cierre del Paso 3 Dejé listo: el glosario base.');
    });
  });
}
