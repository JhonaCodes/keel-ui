import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/shared/shared.dart';

void main() {
  group('el mismo punto escrito distinto es el mismo punto', () {
    test('mayúsculas, acentos y punto final', () {
      expect(
        normalizeForMatch('Migrar la Sesión al nuevo esquema.'),
        normalizeForMatch('migrar la sesion al nuevo esquema'),
      );
    });

    test('un espacio de más en el medio', () {
      expect(
        normalizeForMatch('correr  los\ttests'),
        normalizeForMatch('correr los tests'),
      );
    });

    // La regresión: el recorte iba DESPUÉS de sacar la puntuación, así que
    // un espacio al final le tapaba el ancla y el punto sobrevivía.
    test('un espacio DETRÁS del punto final', () {
      expect(normalizeForMatch('Instalar deps. '), 'instalar deps');
      expect(
        normalizeForMatch('Instalar deps. '),
        normalizeForMatch('instalar deps'),
      );
    });

    test('los signos que abren una pregunta en español', () {
      expect(
        normalizeForMatch('¿Compila en release?'),
        normalizeForMatch('compila en release'),
      );
      expect(normalizeForMatch('¡Listo!'), 'listo');
    });

    test('las comillas de los dos idiomas', () {
      expect(normalizeForMatch('«Cerrar el ciclo»'), 'cerrar el ciclo');
      expect(normalizeForMatch('"Close the loop"'), 'close the loop');
    });
  });

  group('plegar marcas sirve en los dos idiomas', () {
    test('las prestadas del inglés, que la lista castellana no tocaba', () {
      expect(normalizeForMatch('Façade'), 'facade');
      expect(normalizeForMatch('rôle'), 'role');
      expect(normalizeForMatch('naïve'), 'naive');
      expect(normalizeForMatch('São Paulo'), 'sao paulo');
      expect(normalizeForMatch('Ångström'), 'angstrom');
    });

    test('y las de siempre en español', () {
      expect(normalizeForMatch('Año'), 'ano');
      expect(normalizeForMatch('pingüino'), 'pinguino');
      expect(normalizeForMatch('sesión'), 'sesion');
    });

    test('las ligaduras se abren en dos letras', () {
      expect(normalizeForMatch('Encyclopædia'), 'encyclopaedia');
      expect(normalizeForMatch('œuvre'), 'oeuvre');
      expect(normalizeForMatch('Straße'), 'strasse');
    });
  });

  group('lo que NO se toca', () {
    test('la puntuación del medio, que sí distingue', () {
      expect(
        normalizeForMatch('Correr tests, después compilar'),
        'correr tests, despues compilar',
      );
    });

    test('un paréntesis que abre, porque el otro quedaría colgando', () {
      expect(
        normalizeForMatch('(opcional) correr tests'),
        '(opcional) correr tests',
      );
    });

    test('dos puntos distintos siguen siendo distintos', () {
      expect(
        normalizeForMatch('Migrar la sesión'),
        isNot(normalizeForMatch('Migrar el proyecto')),
      );
    });

    test('vacío y espacios sueltos no explotan', () {
      expect(normalizeForMatch(''), '');
      expect(normalizeForMatch('   '), '');
      expect(normalizeForMatch('...'), '');
    });
  });
}
