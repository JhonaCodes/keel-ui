import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/mermaid_diagram.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/session_message_bubble.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalDatabase.markUnavailable();

  testWidgets(
    'el plan y la replanificación conservan un mapa visible en el hilo',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync(
        'keel-plan-diagram-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final projects = ProjectsService.instance.notifier;
      await projects.ready;
      expect(
        projects.createProject(
          name: 'diagram',
          purpose: '',
          workingDirectory: directory.path,
          profileIds: [],
          workflowIds: [],
          ruleNames: [],
          knowledgeBaseNames: [],
        ),
        isNull,
      );
      final projectId = projects.data.projects.single.id;
      projects.createSession(projectId);
      final sessionId = projects.data.projects.single.sessions.single.id;
      projects.setSessionPlan(projectId, sessionId, const [
        (text: 'Comprobar visibilidad', ownerRole: 'experto HTTP'),
        (text: 'Implementar respuesta', ownerRole: 'implementador'),
      ]);
      final legacyMessage =
          projects.data.projects.single.sessions.single.messages.last;
      expect(
        legacyMessage.text,
        contains('Mapa de responsabilidades del plan'),
      );
      expect(legacyMessage.text, contains('experto HTTP'));
      expect(legacyMessage.text, contains('```mermaid\nflowchart TD'));

      const logic =
          'flowchart TD\n  A["Petición"] --> B{"¿Tiene acceso?"}\n  B -->|"Sin acceso"| C["404"]\n  B -->|"Con acceso"| D["Consultar estado"]';
      projects.setSessionPlan(projectId, sessionId, const [
        (text: 'Comprobar visibilidad', ownerRole: 'experto HTTP'),
        (text: 'Implementar respuesta', ownerRole: 'implementador'),
        (text: 'Verificar resultado', ownerRole: 'auditor'),
      ], logicMermaid: logic);
      final restored = Session.fromJson(
        projects.data.projects.single.sessions.single.toJson(),
      );
      final message = restored.messages.last;
      expect(message.role, ChatRole.system);
      expect(message.text, contains('PLAN REPLANIFICADO'));
      expect(message.text, contains(logic));
      expect(restored.messages, contains(legacyMessage));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SessionMessageBubble(
                message: message,
                projectId: projectId,
                sessionId: sessionId,
                author: null,
                nodeTitle: null,
                askedBy: null,
                memberIndex: 0,
                askedByIndex: 0,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(MermaidDiagram), findsOneWidget);
      expect(
        tester.widget<MermaidDiagram>(find.byType(MermaidDiagram)).code.trim(),
        logic,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
