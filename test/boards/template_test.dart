import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/genui/genui.dart';
import 'package:keel_ui/src/modules/boards/model/board.dart';

void main() {
  group('plantillas', () {
    test('reemplaza lo que encuentra', () {
      expect(
        renderTemplate('hola {{quien}}, van {{cuantos}}', {
          'quien': 'mundo',
          'cuantos': '3',
        }),
        'hola mundo, van 3',
      );
    });

    test('tolera los espacios de adentro de las llaves', () {
      expect(renderTemplate('{{ quien }}', {'quien': 'x'}), 'x');
    });

    test('una clave que falta corta con su nombre adentro', () {
      expect(
        () => renderTemplate('{{uno}} {{dos}}', {'uno': 'a'}),
        throwsA(
          isA<MissingTemplateKeys>()
              .having((e) => e.keys, 'keys', ['dos'])
              .having((e) => e.message, 'message', contains('{{dos}}')),
        ),
      );
    });

    test('no expande lo que trae un valor adentro', () {
      expect(renderTemplate('{{a}}', {'a': '{{b}}', 'b': 'nunca'}), '{{b}}');
    });

    test('templateKeysIn no repite y respeta el orden', () {
      expect(templateKeysIn('{{b}} {{a}} {{b}}'), ['b', 'a']);
      expect(templateKeysIn('{{MAYUS}} {{9no}}'), isEmpty);
    });
  });

  group('rutas de JSON', () {
    const json = {
      'data': {
        'items': [
          {'id': 'uno'},
          {'id': 'dos'},
        ],
        'total': 2,
      },
    };

    test('baja por objetos y por listas', () {
      expect(readJsonPath(json, 'data.items.1.id'), 'dos');
      expect(readJsonPath(json, 'data.total'), '2');
    });

    test('un camino que no existe devuelve null en vez de tirar', () {
      expect(readJsonPath(json, 'data.nada'), isNull);
      expect(readJsonPath(json, 'data.items.9.id'), isNull);
      expect(readJsonPath(json, 'data.total.mas'), isNull);
    });

    test('un objeto entero sale como JSON', () {
      expect(readJsonPath(json, 'data.items.0'), '{"id":"uno"}');
    });
  });

  group('armar el pedido', () {
    test('lo que va en la URL se codifica y lo del cuerpo no', () {
      const step = BoardStep(
        kind: BoardStepKind.http,
        method: 'post',
        url: 'https://api/x?q={{texto}}',
        body: '{"q": "{{texto}}"}',
      );

      final request = buildStepRequest(step, {'texto': 'a b&c'});

      expect(request.method, 'POST');
      expect(request.uri.toString(), 'https://api/x?q=a%20b%26c');
      expect(request.body, '{"q": "a b&c"}');
    });

    test('una URL que no se entiende corta antes de salir a la red', () {
      const step = BoardStep(kind: BoardStepKind.http, url: 'no-es-una-url');

      expect(
        () => buildStepRequest(step, const {}),
        throwsA(isA<FormatException>()),
      );
    });

    test('un argumento con espacios sigue siendo un argumento', () {
      const step = BoardStep(
        kind: BoardStepKind.comando,
        command: 'echo',
        args: ['{{mensaje}}', 'fijo'],
      );

      final command = buildStepCommand(step, {'mensaje': 'hola mundo'});

      expect(command.args, ['hola mundo', 'fijo']);
    });
  });
}
