import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/catalog_shape/catalog_shape.dart';

const _root = '/Users/quien/keel-knowledge-bases';

void main() {
  group('relativeToRoot', () {
    test('una carpeta de adentro se vuelve relativa', () {
      expect(relativeToRoot(_root, '$_root/ux-ui-catalog'), 'ux-ui-catalog');
      expect(
        relativeToRoot(_root, '$_root/notas/stacks'),
        'notas/stacks',
      );
    });

    test('una barra de más en la raíz no cambia el resultado', () {
      expect(relativeToRoot('$_root/', '$_root/ux-ui-catalog'), 'ux-ui-catalog');
    });

    test('algo de afuera no es relativo al vault', () {
      expect(relativeToRoot(_root, '/Volumes/Data/otra-cosa'), isNull);
    });

    test('un hermano con el mismo prefijo de texto no cuenta como adentro', () {
      // Sin la barra separadora, "…-bases-viejo" empezaría con "…-bases".
      expect(relativeToRoot(_root, '$_root-viejo/notas'), isNull);
    });

    test('la raíz exacta no es una ruta de adentro', () {
      expect(relativeToRoot(_root, _root), isNull);
      expect(relativeToRoot(_root, '$_root/'), isNull);
    });

    test('sin vault configurado no hay relativa', () {
      expect(relativeToRoot('', '$_root/ux-ui-catalog'), isNull);
    });
  });

  group('absoluteFromRoot', () {
    test('rearma la ruta contra la raíz de esta máquina', () {
      expect(
        absoluteFromRoot(_root, 'ux-ui-catalog'),
        '$_root/ux-ui-catalog',
      );
      expect(
        absoluteFromRoot('$_root/', 'notas/stacks'),
        '$_root/notas/stacks',
      );
    });

    test('una relativa que se escapa del vault se rechaza', () {
      expect(absoluteFromRoot(_root, '../../etc/passwd'), isNull);
      expect(absoluteFromRoot(_root, 'notas/../../afuera'), isNull);
    });

    test('una ruta absoluta disfrazada de relativa se rechaza', () {
      expect(absoluteFromRoot(_root, '/etc/passwd'), isNull);
    });

    test('sin vault configurado no se resuelve nada', () {
      expect(absoluteFromRoot('', 'ux-ui-catalog'), isNull);
    });
  });
}
