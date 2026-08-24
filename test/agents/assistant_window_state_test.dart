import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/agents/model/agent.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/modules/assistant/model/assistant_window_state.dart';

void main() {
  test('el snapshot de Keel AI conserva el proveedor Codex', () {
    final snapshot = AssistantAgentSnapshot.fromAgent(
      Agent(
        id: 'keelai-session',
        name: 'Keel AI',
        model: 'gpt-5.5',
        provider: AgentProvider.codex,
        createdAt: DateTime(2026, 8, 24),
        iconColor: Colors.deepPurple,
        effort: 'medium',
      ),
    );

    final restored = AssistantAgentSnapshot.fromJson(
      snapshot.toJson(),
    ).toAgent();

    expect(restored.provider, AgentProvider.codex);
  });
}
