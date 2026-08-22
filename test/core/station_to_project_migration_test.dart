import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/station_to_project_migration.dart';

/// Una base en memoria. [swallowWrites] simula el peor caso: la base acepta
/// el `put` y no guarda nada.
class _FakeStore implements MigrationStore {
  _FakeStore(this.records, {this.swallowWrites = false});

  final Map<String, Map<String, dynamic>> records;
  final bool swallowWrites;

  @override
  Future<List<({String key, Map<String, dynamic> data})>> entries(
    String prefix,
  ) async => records.entries
      .where((entry) => entry.key.startsWith(prefix))
      .map((entry) => (key: entry.key, data: entry.value))
      .toList();

  @override
  Future<Map<String, dynamic>?> get(String key) async => records[key];

  @override
  Future<void> put(String key, Map<String, dynamic> data) async {
    if (swallowWrites && !key.startsWith('_')) return;
    records[key] = data;
  }

  @override
  Future<void> delete(String key) async => records.remove(key);
}

Map<String, Map<String, dynamic>> _poblada() => {
  'station_p1': {
    'id': 'p1',
    'name': 'aulamas-app',
    'workingDirectory': '/repos/aulamas',
    'taskIds': ['t1', 't2'],
    'activeTaskId': 't1',
  },
  'task_p1_t1': {'id': 't1', 'title': 'migrar login', 'isRunning': false},
  'task_p1_t2': {'id': 't2', 'title': 'goldens', 'isRunning': false},
  'msg_t1_0': {'role': 'user', 'text': 'dale', 'seq': 0},
  'skill_s1': {'id': 's1', 'name': 'algo'},
};

void main() {
  group('migrateStationsToProjects', () {
    test('renombra las claves y deja el payload al día', () async {
      final store = _FakeStore(_poblada());

      await migrateStationsToProjects(store: store);

      expect(
        store.records.keys.where((k) => k.startsWith('station_')),
        isEmpty,
      );
      expect(store.records.keys.where((k) => k.startsWith('task_')), isEmpty);

      final project = store.records['project_p1']!;
      expect(project['name'], 'aulamas-app');
      expect(project['sessionIds'], ['t1', 't2']);
      expect(project['activeSessionId'], 't1');
      expect(project.containsKey('taskIds'), isFalse);
      expect(project.containsKey('activeTaskId'), isFalse);

      expect(store.records['session_p1_t1']!['title'], 'migrar login');
      expect(store.records['session_p1_t2']!['title'], 'goldens');
    });

    test(
      'las claves de los mensajes y de otros catálogos no se tocan',
      () async {
        final store = _FakeStore(_poblada());

        await migrateStationsToProjects(store: store);

        expect(store.records['msg_t1_0']!['text'], 'dale');
        expect(store.records['skill_s1']!['name'], 'algo');
      },
    );

    test('correrla dos veces no duplica ni rompe', () async {
      final store = _FakeStore(_poblada());

      await migrateStationsToProjects(store: store);
      final despuesDeUna = Map<String, Map<String, dynamic>>.from(
        store.records,
      );
      await migrateStationsToProjects(store: store);

      expect(store.records.keys.toSet(), despuesDeUna.keys.toSet());
    });

    test('una base ya migrada no se vuelve a tocar', () async {
      final store = _FakeStore({
        kStationsToProjectsFlagKey: {'projects': 1},
        'station_viejo': {'id': 'viejo'},
      });

      await migrateStationsToProjects(store: store);

      // La bandera manda: si está, ni se mira lo viejo.
      expect(store.records.containsKey('station_viejo'), isTrue);
      expect(store.records.containsKey('project_viejo'), isFalse);
    });

    test('una base vacía queda marcada, sin drama', () async {
      final store = _FakeStore({});

      await migrateStationsToProjects(store: store);

      expect(store.records[kStationsToProjectsFlagKey], isNotNull);
    });

    test(
      'si la escritura no cerró, no borra nada ni se da por hecha',
      () async {
        final store = _FakeStore(_poblada(), swallowWrites: true);

        await migrateStationsToProjects(store: store);

        expect(store.records['station_p1'], isNotNull);
        expect(store.records['task_p1_t1'], isNotNull);
        expect(store.records['task_p1_t2'], isNotNull);
        expect(store.records[kStationsToProjectsFlagKey], isNull);
      },
    );
  });

  group('renamedProjectPayload', () {
    test('un registro sin los campos viejos pasa igual', () {
      final data = {'id': 'p1', 'name': 'x', 'sessionIds': <String>[]};

      expect(renamedProjectPayload(data), data);
    });

    test('no muta el original', () {
      final data = {
        'id': 'p1',
        'taskIds': ['t1'],
      };

      renamedProjectPayload(data);

      expect(data.containsKey('taskIds'), isTrue);
    });
  });
}
