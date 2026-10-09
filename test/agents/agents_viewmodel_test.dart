import 'package:flutter_test/flutter_test.dart';

import 'package:keel_core/integrations/context_mcp/context_mcp_server.dart';
import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_core/core/store/keel_store.dart';
import 'package:keel_ui/src/core/services/flutter_local_db_store.dart';
import 'package:keel_core/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_core/modules/agents/model/agent_model_option.dart';
import 'package:keel_core/modules/agents/model/agent_provider.dart';
import 'package:keel_core/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';

void main() {
  setUpAll(LocalDatabase.markUnavailable);
  setUpAll(() => KeelStore.instance = const FlutterLocalDbStore());

  test('una sesión nueva de Keel AI hereda el proveedor del perfil', () async {
    final profiles = AgentProfilesService.instance.notifier;
    await profiles.ready;
    await profiles.seedReservedProfile(
      AgentProfile(
        id: 'keelai-profile',
        name: kKeelAiHandle,
        role: 'asistente',
        systemPrompt: '',
        model: 'gpt-5.4',
        effort: 'medium',
        provider: AgentProvider.codex,
        createdAt: DateTime(2026),
      ),
    );
    final viewModel = AgentsViewModel();

    final sessionId = viewModel.startNewKeelAiSession();

    final session = viewModel.data.agents.singleWhere(
      (agent) => agent.id == sessionId,
    );
    expect(session.provider, AgentProvider.codex);
  });

  test('cambiar proveedor normaliza el modelo para el CLI de destino', () {
    final viewModel = AgentsViewModel();
    viewModel.createAgent(
      'Agente',
      model: kDefaultClaudeModelAlias,
      fullFileSystemAccess: false,
      effort: 'medium',
    );
    final agentId = viewModel.data.agents.single.id;

    viewModel.setAgentProvider(agentId, AgentProvider.codex);

    final agent = viewModel.data.agents.single;
    expect(agent.provider, AgentProvider.codex);
    expect(agent.model, kCodexDefaultModelAlias);
  });

  test('el aviso de un turno aparece una sola vez en la conversación', () {
    final viewModel = AgentsViewModel();
    viewModel.createAgent(
      'Agente',
      model: kDefaultClaudeModelAlias,
      fullFileSystemAccess: false,
      effort: 'medium',
    );
    final id = viewModel.data.agents.single.id;
    viewModel.appendTurnNotice(id, 'No se pudo cargar el MCP "slack"');
    viewModel.appendTurnNotice(id, 'No se pudo cargar el MCP "slack"');
    expect(
      viewModel.data.agents.single.messages
          .where((message) => message.role == ChatRole.system)
          .length,
      1,
    );
  });

  test(
    'a Claude chat keeps its live process and its profile prompt inline',
    () async {
      // Running, as main() leaves it: with the server down `register`
      // returns null and the turn would look stable for the wrong reason.
      await ContextMcpServer.start();
      final profiles = AgentProfilesService.instance.notifier;
      await profiles.ready;
      const profilePrompt = 'Answer with the verdict first.';
      profiles.createProfile(
        name: 'reviewer',
        role: 'reviews changes',
        systemPrompt: profilePrompt,
        skills: const [],
        rules: const [],
        model: kDefaultClaudeModelAlias,
        effort: 'medium',
      );
      final profileId = profiles.data.profiles
          .singleWhere((profile) => profile.name == 'reviewer')
          .id;
      final viewModel = AgentsViewModel();
      // Its persisted agents load asynchronously and replace the list: an
      // agent created before that lands is gone by the second turn.
      await pumpEventQueue();
      viewModel.createAgent(
        'Reviewer',
        model: kDefaultClaudeModelAlias,
        fullFileSystemAccess: false,
        effort: 'medium',
        profileId: profileId,
      );
      final agentId = viewModel.data.agents.single.id;

      final first = await viewModel.nextTurnSpec(agentId);
      final second = await viewModel.nextTurnSpec(agentId);

      expect(second.liveSpawnKey, first.liveSpawnKey);
      expect(first.additionalSystemPrompt, contains(profilePrompt));
    },
  );

  test('OpenRouter y DeepSeek son proveedores seleccionables', () {
    final viewModel = AgentsViewModel();
    viewModel.createAgent(
      'Agente API',
      model: kDefaultClaudeModelAlias,
      fullFileSystemAccess: false,
      effort: 'medium',
    );
    final agentId = viewModel.data.agents.single.id;

    viewModel.setAgentProvider(agentId, AgentProvider.openRouter);
    var agent = viewModel.data.agents.single;
    expect(agent.provider, AgentProvider.openRouter);
    expect(agent.model, defaultModelFor(AgentProvider.openRouter));

    viewModel.setAgentProvider(agentId, AgentProvider.deepSeek);
    agent = viewModel.data.agents.single;
    expect(agent.provider, AgentProvider.deepSeek);
    expect(agent.model, defaultModelFor(AgentProvider.deepSeek));
  });

  test('los errores nombran al proveedor que realmente ejecutó el turno', () {
    expect(
      AgentProvider.openRouter.turnFailureMessage(),
      'OpenRouter reportó un error en este turno.',
    );
    expect(
      AgentProvider.deepSeek.turnFailureMessage(memberName: 'auditor'),
      'DeepSeek reportó un error en el turno de auditor.',
    );
  });
}
