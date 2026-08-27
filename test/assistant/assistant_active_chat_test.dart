import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';
import 'package:keel_ui/src/modules/assistant/service/assistant_window_bridge.dart';

void main() {
  setUpAll(LocalDatabase.markUnavailable);

  final bridge = AssistantWindowBridge.instance;

  Future<String?> activeChatAfter(String method, [Object? payload]) async {
    final reply = await bridge.handleCall(
      method,
      payload == null ? '{}' : jsonEncode(payload),
    );
    if (reply == null) return null;
    return (jsonDecode(reply) as Map<String, dynamic>)['activeAgentId']
        as String?;
  }

  /// El `init` del ViewModel carga lo guardado y pisa el estado cuando llega.
  Future<List<String>> dosChats() async {
    final agents = AgentsService.instance.notifier;
    await pumpEventQueue();
    for (final name in ['Keel AI viejo', 'Keel AI nuevo']) {
      agents.createAgentSilently(
        name,
        model: kDefaultClaudeModelAlias,
        fullFileSystemAccess: false,
        effort: 'medium',
      );
    }
    return agents.data.agents.map((agent) => agent.id).toList();
  }

  group('el chat activo de la ventana de Keel AI', () {
    test('reconectar NO te mueve del chat que elegiste', () async {
      // Este es el bug que se arregló: la ventana saltaba sola a la
      // conversación más reciente. Elegir uno viejo tiene que aguantar
      // cualquier reconexión o reapertura posterior.
      final ids = await dosChats();
      final viejo = ids.first;

      await activeChatAfter('selectSession', {'agentId': viejo});

      expect(await activeChatAfter('attach'), viejo);
      expect(await activeChatAfter('attach'), viejo);
    });

    test('elegir uno nuevo sí manda', () async {
      final ids = await dosChats();

      await activeChatAfter('selectSession', {'agentId': ids.first});
      await activeChatAfter('selectSession', {'agentId': ids.last});

      expect(await activeChatAfter('attach'), ids.last);
    });

    test(
      'si el chat elegido ya no existe, no se queda apuntando al fantasma',
      () async {
        // Borrarlo desde la app principal dejaría la ventana mostrando un
        // hueco para siempre si nos aferráramos al id muerto.
        final ids = await dosChats();
        final elegido = ids.first;
        await activeChatAfter('selectSession', {'agentId': elegido});

        AgentsService.instance.notifier.deleteAgent(elegido);

        expect(await activeChatAfter('attach'), isNot(elegido));
      },
    );
  });
}
