import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/key_index.dart';

void main() {
  group('KeyIndex', () {
    test('devuelve solo lo que arranca con el prefijo', () {
      final index = KeyIndex({
        'rule_1': {'id': '1', 'name': 'una'},
        'rule_2': {'id': '2', 'name': 'otra'},
        'skill_1': {'id': '1', 'name': 'nada que ver'},
      });

      final rules = index.withPrefix('rule_');

      expect(rules.length, 2);
      expect(rules.map((rule) => rule['name']), containsAll(['una', 'otra']));
    });

    test('entriesWithPrefix conserva la clave entera', () {
      final index = KeyIndex({
        'session_p1_t1': {'id': 't1'},
        'session_p1_t2': {'id': 't2'},
        'project_p1': {'id': 'p1'},
      });

      final sessions = index.entriesWithPrefix('session_');

      expect(sessions.map((entry) => entry.key), [
        'session_p1_t1',
        'session_p1_t2',
      ]);
    });

    test('un prefijo que no existe da vacío, no null', () {
      expect(KeyIndex().withPrefix('nada_'), isEmpty);
      expect(KeyIndex().entriesWithPrefix('nada_'), isEmpty);
      expect(KeyIndex().get('nada'), isNull);
    });

    test('put pisa y delete saca', () {
      final index = KeyIndex({
        'rule_1': {'id': '1', 'name': 'vieja'},
      });

      index.put('rule_1', {'id': '1', 'name': 'nueva'});
      expect(index.get('rule_1')!['name'], 'nueva');

      index.remove('rule_1');
      expect(index.get('rule_1'), isNull);
      expect(index.withPrefix('rule_'), isEmpty);
    });

    test('lo que se guarda no queda atado al mapa de quien lo guardó', () {
      final index = KeyIndex();
      final data = {'id': '1', 'name': 'original'};

      index.put('rule_1', data);
      data['name'] = 'mutado después';

      expect(index.get('rule_1')!['name'], 'original');
    });

    test('lo que se lee no puede corromper el índice', () {
      final index = KeyIndex({
        'rule_1': {'id': '1', 'name': 'original'},
      });

      index.get('rule_1')!['name'] = 'pisado';
      index.withPrefix('rule_').first['name'] = 'pisado también';
      index.entriesWithPrefix('rule_').first.data['name'] = 'y de nuevo';

      expect(index.get('rule_1')!['name'], 'original');
    });

    group('applyPending', () {
      test('una escritura que llegó durante la carga no se pierde', () {
        final index = KeyIndex({
          'rule_1': {'id': '1', 'name': 'la que estaba'},
        });

        index.applyPending({
          'rule_2': {'id': '2', 'name': 'la que entró mientras cargaba'},
        });

        expect(index.withPrefix('rule_').length, 2);
      });

      test('un borrado que llegó durante la carga tampoco', () {
        final index = KeyIndex({
          'rule_1': {'id': '1'},
          'rule_2': {'id': '2'},
        });

        index.applyPending({'rule_1': null});

        expect(index.get('rule_1'), isNull);
        expect(index.withPrefix('rule_').length, 1);
      });

      test('reaplicar lo que la base ya traía no duplica ni rompe', () {
        final index = KeyIndex({
          'rule_1': {'id': '1', 'name': 'la misma'},
        });

        index.applyPending({
          'rule_1': {'id': '1', 'name': 'la misma'},
        });

        expect(index.length, 1);
        expect(index.get('rule_1')!['name'], 'la misma');
      });
    });
  });
}
