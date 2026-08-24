import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';
import 'package:keel_ui/src/modules/assistant/service/assistant_window_bridge.dart';

void main() {
  setUpAll(LocalDatabase.markUnavailable);

  test('el bridge de la ventana cambia a Codex y normaliza el modelo', () async {
    final agents = AgentsService.instance.notifier;
    await Future<void>.delayed(Duration.zero);
    agents.createAgentSilently(
      'Keel AI',
      model: kDefaultClaudeModelAlias,
      fullFileSystemAccess: false,
      effort: 'medium',
    );
    final agentId = agents.data.agents.last.id;

    await AssistantWindowBridge.instance.handleCall(
      'setProvider',
      jsonEncode({'agentId': agentId, 'provider': 'codex'}),
    );

    final agent = agents.data.agents.last;
    expect(agent.provider, AgentProvider.codex);
    expect(agent.model, kCodexDefaultModelAlias);
  });
}
