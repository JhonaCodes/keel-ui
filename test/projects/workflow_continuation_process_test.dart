import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/core/services/user_shell_path.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_case.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';
import 'package:keel_ui/src/modules/skills/viewmodel/skills_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalDatabase.markUnavailable();

  test(
    'el plan continúa hasta implementar y auditar con una consulta entre roles, sin otro mensaje humano',
    () async {
      // This test starts real isolates and provider processes. Never let it run
      // against a user's actual CLI: the wrapper supplies an isolated PATH.
      final expectedCli = File(
        'test/projects/fixtures/continuation_cli/claude',
      ).absolute.path;
      expect(await UserShellPath.locate('claude'), expectedCli);
      final directory = Directory.systemTemp.createTempSync('keel-workflow-');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
      messenger.setMockMethodCallHandler(
        pathProvider,
        (_) async => directory.path,
      );
      addTearDown(() {
        messenger.setMockMethodCallHandler(pathProvider, null);
        directory.deleteSync(recursive: true);
      });
      final profiles = AgentProfilesService.instance.notifier;
      final workflows = WorkflowsService.instance.notifier;
      final projects = ProjectsService.instance.notifier;
      final skills = SkillsService.instance.notifier;
      await Future.wait([
        profiles.ready,
        workflows.ready,
        projects.ready,
        skills.ready,
      ]);
      expect(
        skills.createSkill(
          name: 'visibility-contract',
          content:
              'VISIBILITY_SKILL: valida visibilidad antes del estado del recurso.',
        ),
        isNull,
      );
      for (final role in ['planner', 'implementer', 'auditor']) {
        expect(
          profiles.createProfile(
            name: role,
            role: role,
            systemPrompt: 'Actuá según tu rol.',
            skills: [],
            rules: [],
            model: 'sonnet',
            effort: 'medium',
          ),
          isNull,
        );
      }
      expect(
        workflows.createWorkflow(
          name: 'continuation-fixture',
          whenToApply: 'Continuar el trabajo autorizado.',
          policy: const WorkflowPolicy(
            resolutionRole: 'implementer',
            maxSessionCostUsd: 20,
          ),
          capabilities: const [
            WorkflowCapability(
              id: 'plan',
              title: 'Planificar',
              role: 'planner',
              instruction: 'PLAN_FIXTURE',
              readOnly: true,
            ),
            WorkflowCapability(
              id: 'implement',
              title: 'Implementar',
              role: 'implementer',
              instruction: 'IMPLEMENT_FIXTURE',
              dependencyIds: ['plan'],
            ),
            WorkflowCapability(
              id: 'audit',
              title: 'Auditar',
              role: 'auditor',
              instruction: 'AUDIT_FIXTURE',
              dependencyIds: ['implement'],
              readOnly: true,
              outputContract: 'audit-feedback',
              requiresIndependentOwner: true,
            ),
          ],
        ),
        isNull,
      );
      expect(
        projects.createProject(
          name: 'continuation',
          purpose: 'Integración real del motor',
          workingDirectory: directory.path,
          profileIds: profiles.data.profiles
              .map((profile) => profile.id)
              .toList(),
          workflowIds: [workflows.data.workflows.single.id],
          ruleNames: [],
          knowledgeBaseNames: [],
        ),
        isNull,
      );
      final id = projects.data.projects.single.id;
      projects.createSession(id);

      await projects
          .sendToChannel(
            id,
            'Implementa el cambio y verifícalo con los especialistas.',
          )
          .timeout(const Duration(seconds: 30));

      final session = projects.data.projects.single.sessions.single;
      final recoveredContext = File(
        '${directory.path}/recovered-context.txt',
      ).readAsStringSync();
      expect(
        recoveredContext,
        contains('Implementa el cambio y verifícalo con los especialistas.'),
      );
      expect(recoveredContext, contains('PLAN_FIXTURE'));
      expect(session.decisions, isEmpty);
      expect(
        File('${directory.path}/implementation.txt').existsSync(),
        isTrue,
        reason: session.messages.map((message) => message.text).join('\n'),
      );
      expect(
        File('${directory.path}/implementation.txt').readAsStringSync(),
        '409; visibility preserved\n',
      );
      expect(session.status, SessionStatus.finished);
      expect(session.resolutionCase?.status, ResolutionCaseStatus.completed);
      expect(session.isRunning, isFalse);
      expect(session.waitingForUser, isFalse);
      final specialist = profiles.data.profiles.singleWhere(
        (profile) => profile.name == 'specialist',
      );
      expect(specialist.role, 'Experto en visibilidad y contratos HTTP');
      expect(specialist.skills, ['visibility-contract']);
      expect(
        profiles.data.profiles.any(
          (profile) =>
              profile.name == 'incomplete' || profile.name == 'nonexistent',
        ),
        isFalse,
      );
      final errors = session.messages
          .where((message) => message.role == ChatRole.error)
          .map((message) => message.text)
          .join('\n');
      expect(errors, contains('faltan proposito, instrucciones'));
      expect(errors, contains('Skills inexistentes o vacías: absent-skill'));
      expect(
        specialist.createdByProfileId,
        profiles.data.profiles
            .singleWhere((profile) => profile.name == 'implementer')
            .id,
      );
      expect(session.plan, hasLength(3));
      expect(session.plan.every((item) => item.done), isTrue);
      expect(
        session.messages
            .where((message) => message.role == ChatRole.system)
            .map((message) => message.text)
            .join('\n'),
        contains('```mermaid\nflowchart TD'),
      );
      expect(
        session.messages.where((message) => message.role == ChatRole.user),
        hasLength(1),
      );
      final speakers = session.messages
          .where((message) => message.role == ChatRole.assistant)
          .map(
            (message) => profiles.data.profiles
                .firstWhere((profile) => profile.id == message.authorProfileId)
                .name,
          );
      expect(speakers, [
        'planner',
        'implementer',
        'implementer',
        'implementer', // Registro visible del especialista.
        'specialist',
        'implementer',
        'implementer',
        'auditor',
      ]);
      final turns = File('${directory.path}/provider-turns.jsonl')
          .readAsLinesSync()
          .map((line) => jsonDecode(line) as Map<String, dynamic>)
          .toList();
      expect(turns.map((turn) => turn['budget']), [
        20,
        19.5,
        19,
        18.5,
        18,
        17.5,
        17,
      ]);
      expect(session.usage.reportedCostUsd, 3.5);
      final implementationPrompt = turns[1]['prompt'] as String;
      expect(implementationPrompt, contains('REPARTO DEL TRABAJO ENTRE AGENTES'));
      expect(implementationPrompt, contains('@planner (planner)'));
      expect(implementationPrompt, contains('@auditor (auditor)'));
      expect(implementationPrompt, contains('depende de: plan'));
      expect(implementationPrompt, contains('audit-feedback'));
    },
    skip: Platform.environment['KEEL_FAKE_WORKFLOW'] != '1',
  );
}
