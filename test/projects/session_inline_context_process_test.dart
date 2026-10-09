import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_core/core/host/keel_host.dart';
import 'package:keel_core/core/services/user_shell_path.dart';
import 'package:keel_core/core/store/keel_store.dart';
import 'package:keel_core/integrations/context_mcp/context_mcp_server.dart';
import 'package:keel_core/modules/projects/model/resolution_case.dart';
import 'package:keel_core/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/core/host/keel_host_impl.dart';
import 'package:keel_ui/src/core/services/flutter_local_db_store.dart';
import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/rules/viewmodel/rules_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalDatabase.markUnavailable();
  KeelStore.instance = const FlutterLocalDbStore();
  KeelHost.instance = const KeelHostImpl();

  test('a claude member runs its node with the project rules inline and '
      'without the on-demand context server', () async {
    // Real isolates and provider processes. Never against the user's CLI:
    // the wrapper script puts the fixture first on an isolated PATH.
    final expectedCli = File(
      'test/projects/fixtures/context_cli/claude',
    ).absolute.path;
    expect(await UserShellPath.locate('claude'), expectedCli);
    // Running, as main() leaves it: with the server down no turn could
    // register its context, and the rules would look inline by accident.
    await ContextMcpServer.start();
    final directory = Directory.systemTemp.createTempSync('keel-context-');
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
    final rules = RulesService.instance.notifier;
    await Future.wait([
      profiles.ready,
      workflows.ready,
      projects.ready,
      rules.ready,
    ]);
    const ruleText = 'RULE_FIXTURE: nothing is committed without approval.';
    expect(rules.createRule(name: 'approval', content: ruleText), isNull);
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
        name: 'context-fixture',
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
        name: 'context',
        purpose: 'Reglas del proyecto en el prompt',
        workingDirectory: directory.path,
        profileIds: profiles.data.profiles
            .map((profile) => profile.id)
            .toList(),
        workflowIds: [workflows.data.workflows.single.id],
        ruleNames: ['approval'],
        knowledgeBaseNames: [],
      ),
      isNull,
    );
    final projectId = projects.data.projects.single.id;
    projects.createSession(projectId);

    await projects
        .sendToChannel(projectId, 'Implementa el cambio.')
        .timeout(const Duration(seconds: 30));

    final argv =
        (jsonDecode(File('${directory.path}/argv.json').readAsStringSync())
                as List)
            .cast<String>();
    final systemPrompt = argv[argv.indexOf('--append-system-prompt') + 1];
    expect(systemPrompt, contains(ruleText));
    expect(
      File('${directory.path}/mcp-config.json').readAsStringSync(),
      isNot(contains(kContextMcpServerKey)),
    );
    expect(
      projects.data.projects.single.sessions.single.resolutionCase?.status,
      ResolutionCaseStatus.completed,
    );
  }, skip: Platform.environment['KEEL_FAKE_CONTEXT'] != '1');
}
