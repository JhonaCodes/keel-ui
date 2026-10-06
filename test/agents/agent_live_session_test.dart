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
    'dos mensajes seguidos a un agente claude los atiende el mismo proceso',
    () async {
      // Starts real isolates and a real process. Never against the user's
      // own CLI: test/run_agent_live_session.sh supplies an isolated PATH.
      final fakeCli = File(
        'test/agents/fixtures/live_cli/claude',
      ).absolute.path;
      expect(await UserShellPath.locate('claude'), fakeCli);

      final agents = AgentsService.instance.notifier;
      // The persisted-agents load is fire-and-forget from `init`; let it land
      // before creating one, or it replaces the list afterwards.
      await pumpEventQueue();
      final agentId = agents.createAgentSilently(
        'vivo',
        model: 'sonnet',
        fullFileSystemAccess: false,
        effort: 'medium',
        provider: AgentProvider.claude,
      );

      await agents.sendMessage(agentId, 'uno');
      await agents.sendMessage(agentId, 'dos');

      // Each answer is the pid of the process that served the turn. Two
      // different pids mean every message paid for a fresh `claude` —
      // the ~2 s the user sees on each send.
      final answers = agents.data.agents
          .firstWhere((agent) => agent.id == agentId)
          .messages
          .where((message) => message.role == ChatRole.assistant)
          .map((message) => message.text.trim())
          .toList();
      expect(answers, hasLength(2));
      expect(answers.first, startsWith('pid='));
      expect(answers.last, answers.first);
    },
    skip: Platform.environment['KEEL_FAKE_LIVE_CLI'] != '1',
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
