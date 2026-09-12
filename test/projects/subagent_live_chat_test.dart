import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/modules/agents/model/agent_tool_activity.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/agent_activity_indicator.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/session_subagent.dart';
import 'package:keel_ui/src/modules/projects/ui/view/session_chat_view.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/session_subagent_card.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/turn_phase_label.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';

void main() {
  testWidgets(
    'session notifications show child progress and remove its animation on completion',
    (tester) async {
      LocalDatabase.markUnavailable();
      final vm = ProjectsService.instance.notifier;
      await vm.ready;
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => tester.view.resetPhysicalSize());
      final started = DateTime.utc(2026);
      final child = SessionSubagent(
        id: 'child',
        parentProfileId: 'owner',
        agentType: 'Explore',
        ask: 'Revisar la ejecución',
        prompt: 'Revisar la ejecución',
        startedAt: started,
      );
      final session = Session(id: 's', title: 'Chat', createdAt: started);
      final project = Project(
        id: 'p',
        name: 'keel',
        purpose: '',
        workingDirectory: '/tmp',
        createdAt: started,
        activeSessionId: 's',
        sessions: [session],
      );
      vm.updateState(
        ProjectsState(projects: [project], selectedProjectId: 'p'),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ReactiveViewModelBuilder<ProjectsViewModel, ProjectsState>(
              viewmodel: vm,
              build: (state, viewmodel, keep) =>
                  SessionChatView(project: state.selectedProject!),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(SessionSubagentCard), findsNothing);
      vm.updateState(
        ProjectsState(
          projects: [
            project.copyWith(
              sessions: [
                session.copyWith(subagents: [child]),
              ],
            ),
          ],
          selectedProjectId: 'p',
        ),
      );
      await tester.pump();
      expect(find.byType(SessionSubagentCard), findsOneWidget);
      expect(find.byType(TurnPhaseLabel), findsOneWidget);
      final working = child.copyWith(
        phase: .working,
        activity: const AgentToolActivity(
          kind: .read,
          label: 'Leyendo session.dart',
        ),
      );
      vm.updateState(
        ProjectsState(
          projects: [
            project.copyWith(
              sessions: [
                session.copyWith(subagents: [working]),
              ],
            ),
          ],
          selectedProjectId: 'p',
        ),
      );
      await tester.pump();
      expect(find.byType(AgentActivityIndicator), findsOneWidget);
      expect(find.text('Leyendo session.dart'), findsOneWidget);
      vm.updateState(
        ProjectsState(
          projects: [
            project.copyWith(
              sessions: [
                session.copyWith(
                  subagents: [
                    working.copyWith(
                      phase: .done,
                      result: 'Verificado',
                      clearActivity: true,
                      finishedAt: started.add(const Duration(minutes: 1)),
                    ),
                  ],
                ),
              ],
            ),
          ],
          selectedProjectId: 'p',
        ),
      );
      await tester.pump();
      expect(find.byType(AgentActivityIndicator), findsNothing);
      expect(find.byType(TurnPhaseLabel), findsNothing);
      expect(find.text('Verificado'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
