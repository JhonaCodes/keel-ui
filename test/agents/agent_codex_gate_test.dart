import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_core/core/store/keel_store.dart';
import 'package:keel_ui/src/core/services/flutter_local_db_store.dart';
import 'package:keel_core/core/services/user_shell_path.dart';
import 'package:keel_core/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalDatabase.markUnavailable();
  KeelStore.instance = const FlutterLocalDbStore();

  test(
    'a codex turn in a 1:1 chat carries Keel\'s permission gate',
    () async {
      // Never against the user's own codex: test/run_agent_codex_chat.sh
      // puts a fake one first on an isolated PATH.
      final fakeCodex = File('test/agents/fixtures/codex_cli/codex').absolute;
      expect(await UserShellPath.locate('codex'), fakeCodex.path);

      final agents = AgentsService.instance.notifier;
      await pumpEventQueue();
      final agentId = agents.createAgentSilently(
        'codex-gate',
        model: '',
        fullFileSystemAccess: false,
        effort: 'medium',
        provider: AgentProvider.codex,
      );

      await agents.sendMessage(agentId, 'crea un archivo');

      // Without the gate, codex writes and runs commands with no one asked.
      final argv = File(
        Platform.environment['KEEL_CODEX_ARGV_LOG']!,
      ).readAsStringSync();
      expect(argv, contains('keel-decision-gate'));
      expect(argv, contains('--dangerously-bypass-hook-trust'));
    },
    skip: Platform.environment['KEEL_FAKE_CODEX_CHAT'] != '1',
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
