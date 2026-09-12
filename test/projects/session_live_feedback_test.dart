import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agents/model/agent_tool_activity.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/agent_activity_indicator.dart';
import 'package:keel_ui/src/modules/projects/model/session_live_turn.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/session_live_turn_strip.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/turn_phase_label.dart';

void main() {
  testWidgets('open turn distinguishes awaiting output, reasoning and tools', (
    tester,
  ) async {
    final member = AgentProfile(
      id: 'agent',
      name: 'expert',
      role: 'Expert',
      systemPrompt: '',
      model: 'sonnet',
      effort: 'normal',
      createdAt: DateTime(2026),
    );
    final state = ValueNotifier(const SessionLiveTurn(profileId: 'agent'));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ValueListenableBuilder<SessionLiveTurn>(
            valueListenable: state,
            builder: (context, turn, child) =>
                SessionLiveTurnStrip(turn: turn, members: [member]),
          ),
        ),
      ),
    );
    expect(find.text('Awaiting provider output…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(TurnPhaseLabel), findsNothing);
    state.value = state.value.copyWith(reasoning: 'Inspecting evidence');
    await tester.pump();
    expect(find.text('Awaiting provider output…'), findsNothing);
    expect(find.byType(TurnPhaseLabel), findsOneWidget);
    state.value = state.value.copyWith(
      phase: .working,
      activity: AgentToolActivity.fromToolUse('Read', {
        'file_path': 'lib/main.dart',
      }),
    );
    await tester.pump();
    expect(find.byType(AgentActivityIndicator), findsOneWidget);
    state.value = state.value.copyWith(
      phase: .writing,
      clearActivity: true,
      clearReasoning: true,
    );
    await tester.pump();
    expect(find.byType(AgentActivityIndicator), findsNothing);
    expect(find.byType(TurnPhaseLabel), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    expect(tester.takeException(), isNull);
  });
}
