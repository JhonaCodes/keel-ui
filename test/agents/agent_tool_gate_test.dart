import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_core/core/store/keel_store.dart';
import 'package:keel_ui/src/core/services/flutter_local_db_store.dart';
import 'package:keel_core/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';
import 'package:keel_ui/src/modules/settings/viewmodel/settings_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalDatabase.markUnavailable();
  KeelStore.instance = const FlutterLocalDbStore();

  test(
    'the 1:1 gate waits for the person: once lets one call through, always '
    'grants the tool for the next ones',
    () async {
      final settings = SettingsService.instance.notifier;
      await settings.ready;
      final agents = AgentsService.instance.notifier;
      await pumpEventQueue();
      final agentId = agents.createAgentSilently(
        'gate-1a1',
        model: '',
        fullFileSystemAccess: false,
        effort: 'medium',
        provider: AgentProvider.codex,
      );
      // A turn is running: that is when the gate can be asked.
      agents.updateState(
        agents.data.copyWith(
          agents: [
            for (final agent in agents.data.agents)
              agent.id == agentId ? agent.copyWith(isStreaming: true) : agent,
          ],
        ),
      );
      pending() => agents.data.agents
          .firstWhere((agent) => agent.id == agentId)
          .pendingPermission;

      final once = agents.decideToolUse(
        agentId: agentId,
        toolName: 'Bash',
        toolInput: 'flutter pub get',
      );
      await pumpEventQueue();
      expect(pending()?.blocking, isTrue);
      expect(pending()?.message, contains('flutter pub get'));
      agents.respondToPermissionRequest(agentId, grant: true);
      expect((await once).allow, isTrue);
      expect(pending(), isNull);
      expect(settings.data.extraAllowedTools, isNot(contains('Bash')));

      final always = agents.decideToolUse(
        agentId: agentId,
        toolName: 'Bash',
        toolInput: 'git status',
      );
      await pumpEventQueue();
      agents.respondToPermissionRequest(agentId, grant: true, always: true);
      expect((await always).allow, isTrue);

      // Granted for good: the next call does not ask.
      final next = await agents.decideToolUse(
        agentId: agentId,
        toolName: 'Bash',
        toolInput: 'ls',
      );
      expect(next.allow, isTrue);
      expect(pending(), isNull);
      settings.setExtraToolEnabled('Bash', false);
    },
  );
}
