import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_core/core/store/keel_store.dart';
import 'package:keel_ui/src/core/services/flutter_local_db_store.dart';
import 'package:keel_core/core/services/user_shell_path.dart';
import 'package:keel_core/modules/agents/model/agent_provider.dart';
import 'package:keel_core/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalDatabase.markUnavailable();
  KeelStore.instance = const FlutterLocalDbStore();

  test(
    'an OpenCode turn asks Keel for permission and answers in the chat',
    () async {
      // test/run_agent_opencode.sh puts a fake opencode first on the PATH.
      final fake = File('test/agents/fixtures/opencode_cli/opencode').absolute;
      expect(await UserShellPath.locate('opencode'), fake.path);

      final agents = AgentsService.instance.notifier;
      await pumpEventQueue();
      final agentId = agents.createAgentSilently(
        'opencode-1a1',
        model: 'fake/model-a',
        fullFileSystemAccess: false,
        effort: 'medium',
        provider: AgentProvider.openCode,
      );
      agent() => agents.data.agents.firstWhere((entry) => entry.id == agentId);

      final turn = agents.sendMessage(agentId, 'corre echo hola');
      for (var i = 0; i < 300; i++) {
        if (agent().pendingPermission?.blocking ?? false) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(agent().pendingPermission?.blocking, isTrue);
      expect(agent().pendingPermission?.message, contains('echo hola'));

      agents.respondToPermissionRequest(agentId, grant: true);
      await turn.timeout(const Duration(seconds: 30));

      final answers = agent().messages
          .where((message) => message.role == ChatRole.assistant)
          .map((message) => message.text.trim());
      expect(answers.last, 'listo');
      expect(
        File(Platform.environment['KEEL_OPENCODE_LOG']!).readAsStringSync(),
        contains('per_1 once'),
      );
    },
    skip: Platform.environment['KEEL_FAKE_OPENCODE'] != '1',
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test(
    'OpenCode may run at most 4 subagent tasks at once',
    () async {
      final agents = AgentsService.instance.notifier;
      await pumpEventQueue();
      final agentId = agents.createAgentSilently(
        'opencode-tasks',
        model: 'fake/model-a',
        fullFileSystemAccess: false,
        effort: 'medium',
        provider: AgentProvider.openCode,
      );

      await agents
          .sendMessage(agentId, 'abre cinco tareas en paralelo')
          .timeout(const Duration(seconds: 30));

      final replies = File(Platform.environment['KEEL_OPENCODE_LOG']!)
          .readAsLinesSync()
          .where((line) => line.startsWith('per_t'))
          .map((line) => line.split(' ').last)
          .toList();
      expect(replies.where((reply) => reply == 'once'), hasLength(4));
      expect(replies.where((reply) => reply == 'reject'), hasLength(1));
    },
    skip: Platform.environment['KEEL_FAKE_OPENCODE'] != '1',
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
