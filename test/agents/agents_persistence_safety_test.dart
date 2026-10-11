import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_core/core/store/keel_store.dart';
import 'package:keel_core/modules/agents/model/agent.dart';
import 'package:keel_core/modules/agents/model/agent_model_option.dart';
import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';

/// A key/value store in memory, so the test can read what is really
/// persisted. [agentsGate], while set, holds the agents' load open — the
/// window a slow start leaves between the app showing and the chats arriving.
class _MemoryStore implements KeelStore {
  final Map<String, Map<String, dynamic>> records = {};
  Completer<void>? agentsGate;

  @override
  Future<void> put(String key, Map<String, dynamic> data) async =>
      records[key] = data;

  @override
  Future<Map<String, dynamic>?> get(String key) async => records[key];

  @override
  Future<void> delete(String key) async => records.remove(key);

  @override
  Future<List<Map<String, dynamic>>> getAllWithPrefix(String prefix) async {
    final gate = agentsGate;
    if (prefix == 'agent_' && gate != null) await gate.future;
    return [
      for (final entry in records.entries)
        if (entry.key.startsWith(prefix)) entry.value,
    ];
  }

  @override
  Future<List<({String key, Map<String, dynamic> data})>> entriesWithPrefix(
    String prefix,
  ) async => [
    for (final entry in records.entries)
      if (entry.key.startsWith(prefix)) (key: entry.key, data: entry.value),
  ];

  @override
  Future<void> replaceAllWithPrefix(
    String prefix,
    List<Map<String, dynamic>> items,
  ) async {
    records.removeWhere((key, _) => key.startsWith(prefix));
    for (final item in items) {
      records['$prefix${item['id']}'] = item;
    }
  }

  Set<String> get agentIds => {
    for (final key in records.keys)
      if (key.startsWith('agent_')) key.substring('agent_'.length),
  };
}

Map<String, dynamic> _savedChat(String id) => Agent(
  id: id,
  name: 'keelai',
  model: kDefaultClaudeModelAlias,
  createdAt: DateTime(2026, 10, 2),
  iconColorValue: 0xFF5C6BC0,
  effort: 'medium',
).toJson();

void main() {
  setUpAll(LocalDatabase.markUnavailable);

  late _MemoryStore store;

  setUp(() {
    store = _MemoryStore();
    KeelStore.instance = store;
  });

  group('las conversaciones guardadas sobreviven', () {
    test('un registro ilegible no esconde ni borra las demás', () async {
      // Lo que se vio en la ventana de Keel AI: un solo registro que no se
      // puede leer dejaba la lista entera vacía, y borrar el chat que la
      // ventana creó encima reescribía la base con esa lista vacía.
      store.records['agent_viejo-1'] = _savedChat('viejo-1');
      store.records['agent_viejo-2'] = _savedChat('viejo-2');
      store.records['agent_roto'] = {'id': 'roto', 'name': 'sin modelo'};

      final viewModel = AgentsViewModel();
      await pumpEventQueue();

      expect(
        viewModel.data.agents.map((agent) => agent.id),
        containsAll(['viejo-1', 'viejo-2']),
      );

      viewModel.deleteAgent(_createLoose(viewModel));
      await pumpEventQueue();

      expect(store.agentIds, {'viejo-1', 'viejo-2', 'roto'});
    });

    test('borrar antes de que termine la carga no se lleva lo que no '
        'llegó todavía', () async {
      store.records['agent_viejo-1'] = _savedChat('viejo-1');
      store.agentsGate = Completer<void>();

      final viewModel = AgentsViewModel();
      await pumpEventQueue();
      final temprano = _createLoose(viewModel);
      final otro = _createLoose(viewModel);
      viewModel.deleteAgent(temprano);
      await pumpEventQueue();

      store.agentsGate!.complete();
      await viewModel.ready;
      await pumpEventQueue();

      expect(store.agentIds, containsAll(['viejo-1', otro]));
      expect(store.agentIds, isNot(contains(temprano)));
      // Lo creado mientras cargaba tampoco desaparece de la pantalla.
      expect(
        viewModel.data.agents.map((agent) => agent.id),
        containsAll(['viejo-1', otro]),
      );
    });
  });
}

String _createLoose(AgentsViewModel viewModel) => viewModel.createAgentSilently(
  'keelai',
  model: kDefaultClaudeModelAlias,
  fullFileSystemAccess: false,
  effort: 'medium',
);
