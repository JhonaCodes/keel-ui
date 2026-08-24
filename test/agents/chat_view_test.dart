import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/agents/model/agent.dart';
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/modules/agents/service/chat_actions.dart';
import 'package:keel_ui/src/modules/agents/ui/view/chat_view.dart';

final _epoch = DateTime(2026, 8, 24);

void main() {
  testWidgets(
    'elegir Codex actualiza el proveedor y muestra su modelo por defecto',
    (tester) async {
      late _RecordingChatActions actions;
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 1200,
                child: _ChatHarness(
                  onActionsReady: (value) => actions = value,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('provider-claude')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Codex'));
      await tester.pumpAndSettle();

      expect(actions.providerChanges, [('keelai-session', AgentProvider.codex)]);
      expect(find.byKey(const ValueKey('model-codex')), findsOneWidget);
      expect(find.text('El de tu config de codex'), findsOneWidget);
    },
  );

  testWidgets('OpenRouter y DeepSeek aparecen como proveedores del chat', (
    tester,
  ) async {
    late _RecordingChatActions actions;
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            child: _ChatHarness(onActionsReady: (value) => actions = value),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('provider-claude')));
    await tester.pumpAndSettle();
    expect(find.text('OpenRouter'), findsOneWidget);
    expect(find.text('DeepSeek'), findsOneWidget);

    await tester.tap(find.text('OpenRouter'));
    await tester.pumpAndSettle();
    expect(
      actions.providerChanges,
      [('keelai-session', AgentProvider.openRouter)],
    );
    expect(find.byKey(const ValueKey('model-openrouter')), findsOneWidget);
  });
}

class _ChatHarness extends StatefulWidget {
  const _ChatHarness({required this.onActionsReady});

  final ValueChanged<_RecordingChatActions> onActionsReady;

  @override
  State<_ChatHarness> createState() => _ChatHarnessState();
}

class _ChatHarnessState extends State<_ChatHarness> {
  late Agent _agent;
  late final _RecordingChatActions _actions;

  @override
  void initState() {
    super.initState();
    _agent = Agent(
      id: 'keelai-session',
      name: 'Keel AI',
      model: kDefaultClaudeModelAlias,
      provider: AgentProvider.claude,
      createdAt: _epoch,
      iconColor: Colors.deepPurple,
      effort: 'medium',
    );
    _actions = _RecordingChatActions(
      onProviderChanged: (agentId, provider) {
        setState(() {
          _agent = _agent.copyWith(
            provider: provider,
            model: defaultModelFor(provider),
          );
        });
      },
    );
    widget.onActionsReady(_actions);
  }

  @override
  Widget build(BuildContext context) {
    return ChatView(agent: _agent, actions: _actions);
  }
}

class _RecordingChatActions extends LocalChatActions {
  _RecordingChatActions({required this.onProviderChanged});

  final void Function(String agentId, AgentProvider provider)
  onProviderChanged;
  final List<(String, AgentProvider)> providerChanges = [];

  @override
  void setAgentProvider(String agentId, AgentProvider provider) {
    providerChanges.add((agentId, provider));
    onProviderChanged(agentId, provider);
  }
}
