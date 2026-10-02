import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/core/services/user_shell_path.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_case.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalDatabase.markUnavailable();

  test('«Enviar ahora» con un nodo de claude trabajando le entrega el mensaje '
      'en su próximo paso: no corta el turno ni relanza el nodo', () async {
    // Real isolates and provider processes. Never against the user's CLI:
    // the wrapper script puts the fixture first on an isolated PATH.
    final expectedCli = File(
      'test/projects/fixtures/steer_cli/claude',
    ).absolute.path;
    expect(await UserShellPath.locate('claude'), expectedCli);
    final directory = Directory.systemTemp.createTempSync('keel-steer-');
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
    await Future.wait([profiles.ready, workflows.ready, projects.ready]);
    expect(
      profiles.createProfile(
        name: 'implementer',
        role: 'implementer',
        systemPrompt: 'Implementa lo pedido.',
        skills: [],
        rules: [],
        model: 'sonnet',
        effort: 'medium',
      ),
      isNull,
    );
    expect(
      workflows.createWorkflow(
        name: 'steer-fixture',
        whenToApply: 'Implementar un cambio.',
        policy: const WorkflowPolicy(
          resolutionRole: 'implementer',
          maxSessionCostUsd: 20,
        ),
        capabilities: const [
          WorkflowCapability(
            id: 'implement',
            title: 'Implementar',
            role: 'implementer',
            instruction: 'IMPLEMENT_FIXTURE',
          ),
        ],
      ),
      isNull,
    );
    expect(
      projects.createProject(
        name: 'steer',
        purpose: 'Mensaje a mitad de turno',
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
    final projectId = projects.data.projects.single.id;
    projects.createSession(projectId);
    final sessionId = projects.data.projects.single.sessions.single.id;

    final run = projects.sendToChannel(projectId, 'Implementa el cambio.');

    // The fixture marks when its tool is "running": that is when the user
    // writes.
    final waiting = File('${directory.path}/turn-waiting');
    final started = DateTime.now();
    while (!waiting.existsSync()) {
      if (DateTime.now().difference(started) > const Duration(seconds: 20)) {
        fail('el nodo nunca llegó a su herramienta');
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final queuedId = await projects.queueSessionMessage(
      projectId,
      sessionId,
      'cambio de rumbo',
    );
    expect(projects.canSteerSession(sessionId), isTrue);
    await projects.sendQueuedSessionMessageNow(projectId, sessionId, queuedId!);
    await run.timeout(const Duration(seconds: 30));

    final session = projects.data.projects.single.sessions.single;
    final stdinLines = File('${directory.path}/stdin.jsonl').readAsLinesSync();
    expect(stdinLines, hasLength(2));
    expect(jsonDecode(stdinLines[1]), {
      'type': 'user',
      'message': {'role': 'user', 'content': 'cambio de rumbo'},
      'priority': 'next',
    });
    // One process for the whole node: nothing was killed and relaunched.
    expect(
      File('${directory.path}/invocations.log').readAsLinesSync(),
      hasLength(1),
    );
    final systemTexts = session.messages
        .where((message) => message.role == ChatRole.system)
        .map((message) => message.text)
        .join('\n');
    expect(systemTexts, isNot(contains('Turno interrumpido')));
    expect(systemTexts, contains('Entregado a @implementer'));
    expect(
      session.messages
          .where((message) => message.role == ChatRole.assistant)
          .map((message) => message.text)
          .join('\n'),
      contains('RECIBIDO: cambio de rumbo'),
    );
    expect(session.queuedMessages, isEmpty);
    expect(session.resolutionCase?.status, ResolutionCaseStatus.completed);
  }, skip: Platform.environment['KEEL_FAKE_STEER'] != '1');

  test(
    'con un proveedor sin canal (codex) el corte retoma el nodo en UN turno '
    'de continuación con el mensaje adentro, no con su contrato completo',
    () async {
      final directory = Directory.systemTemp.createTempSync('keel-cut-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final profiles = AgentProfilesService.instance.notifier;
      final workflows = WorkflowsService.instance.notifier;
      final projects = ProjectsService.instance.notifier;
      await Future.wait([profiles.ready, workflows.ready, projects.ready]);
      expect(
        profiles.createProfile(
          name: 'coder',
          role: 'coder',
          systemPrompt: 'Implementa lo pedido.',
          skills: [],
          rules: [],
          model: 'gpt-5',
          effort: 'medium',
          provider: AgentProvider.codex,
        ),
        isNull,
      );
      expect(
        workflows.createWorkflow(
          name: 'cut-fixture',
          whenToApply: 'Implementar un cambio con codex.',
          policy: const WorkflowPolicy(
            resolutionRole: 'coder',
            maxSessionCostUsd: 20,
          ),
          capabilities: const [
            WorkflowCapability(
              id: 'implement',
              title: 'Implementar',
              role: 'coder',
              instruction: 'IMPLEMENT_FIXTURE',
            ),
          ],
        ),
        isNull,
      );
      expect(
        projects.createProject(
          name: 'cut',
          purpose: 'Corte con proveedor sin canal',
          workingDirectory: directory.path,
          profileIds: [
            profiles.data.profiles
                .singleWhere((profile) => profile.name == 'coder')
                .id,
          ],
          workflowIds: [
            workflows.data.workflows
                .singleWhere((workflow) => workflow.name == 'cut-fixture')
                .id,
          ],
          ruleNames: [],
          knowledgeBaseNames: [],
        ),
        isNull,
      );
      final projectId = projects.data.projects
          .singleWhere((project) => project.name == 'cut')
          .id;
      projects.createSession(projectId);
      final sessionId = projects.data.projects
          .singleWhere((project) => project.id == projectId)
          .sessions
          .single
          .id;

      final run = projects.sendToChannel(projectId, 'Implementa el cambio.');

      final waiting = File('${directory.path}/turn-waiting');
      final started = DateTime.now();
      while (!waiting.existsSync()) {
        if (DateTime.now().difference(started) > const Duration(seconds: 20)) {
          fail('el nodo nunca llegó a su herramienta');
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      // Without this the kill can land before Keel saw the thread id.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final queuedId = await projects.queueSessionMessage(
        projectId,
        sessionId,
        'usa la otra descarga',
      );
      expect(projects.canSteerSession(sessionId), isFalse);
      await projects.sendQueuedSessionMessageNow(
        projectId,
        sessionId,
        queuedId!,
      );
      await run.timeout(const Duration(seconds: 30));

      // The cut turn and ONE continuation: no separate turn for the message.
      expect(File('${directory.path}/invocations.log').readAsLinesSync(), [
        endsWith(' new'),
        endsWith(' resume'),
      ]);
      final resumed = File(
        '${directory.path}/resumed-prompt.txt',
      ).readAsStringSync();
      expect(resumed, contains('CONTINUACIÓN DEL NODO "Implementar"'));
      expect(resumed, contains('usa la otra descarga'));
      expect(resumed, isNot(contains('Pedido original')));
      final session = projects.data.projects
          .singleWhere((project) => project.id == projectId)
          .sessions
          .single;
      expect(
        session.messages.where(
          (message) =>
              message.role == ChatRole.user &&
              message.text == 'usa la otra descarga',
        ),
        hasLength(1),
      );
      expect(session.queuedMessages, isEmpty);
      expect(session.resolutionCase?.status, ResolutionCaseStatus.completed);
    },
    skip: Platform.environment['KEEL_FAKE_STEER'] != '1',
  );
}
