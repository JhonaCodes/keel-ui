import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_core/core/services/user_shell_path.dart';
import 'package:keel_core/core/store/keel_store.dart';
import 'package:keel_core/integrations/task_runner/task_runner.dart';
import 'package:keel_core/modules/agents/model/agent.dart';
import 'package:keel_core/modules/agents/model/agent_model_option.dart';
import 'package:keel_core/modules/agents/model/agent_provider.dart';
import 'package:keel_core/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/core/services/flutter_local_db_store.dart';
import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalDatabase.markUnavailable();
  KeelStore.instance = const FlutterLocalDbStore();
  final isFakeRun = Platform.environment['KEEL_FAKE_CHAT'] == '1';

  test('«Enviar ahora» in a claude chat hands the message to the running turn '
      'without cutting it', () async {
    // Real isolates and provider processes. Never against the user's CLI:
    // the wrapper script puts the fixture first on an isolated PATH.
    expect(
      await UserShellPath.locate('claude'),
      File('test/agents/fixtures/chat_cli/claude').absolute.path,
    );
    final logs = _freshLogs('claude');
    final viewModel = AgentsViewModel();
    // Its persisted agents load asynchronously and replace the list.
    await pumpEventQueue();
    viewModel.createAgent(
      'Claude chat',
      model: kDefaultClaudeModelAlias,
      fullFileSystemAccess: false,
      effort: 'medium',
    );
    final agentId = viewModel.data.agents.single.id;
    addTearDown(() => TaskRunner.closeLive(agentId));

    final firstTurn = viewModel.sendMessage(agentId, 'Implementa el cambio.');
    await _untilExists(File('${logs.path}/turn-waiting'));
    await viewModel.sendMessage(agentId, 'cambio de rumbo');
    final queued = viewModel.data.agents.single.queuedMessages.single;
    // Bounded: a message lost on a dying process never gets its turn to
    // end, and the assertions below say what went missing.
    await Future.wait([
      viewModel.sendQueuedMessageNow(agentId, queued.id),
      firstTurn,
    ]).timeout(const Duration(seconds: 20), onTimeout: () => []);

    final stdinLines = File('${logs.path}/stdin.jsonl').readAsLinesSync();
    final agent = viewModel.data.agents.single;
    expect(
      _textsOf(agent, ChatRole.assistant),
      contains('RECIBIDO: cambio de rumbo'),
    );
    expect(stdinLines, hasLength(2));
    expect(jsonDecode(stdinLines[1]), {
      'type': 'user',
      'message': {'role': 'user', 'content': 'cambio de rumbo'},
      'priority': 'next',
    });
    // One process for the whole conversation: nothing killed and relaunched.
    expect(
      File('${logs.path}/invocations.log').readAsLinesSync(),
      hasLength(1),
    );
    expect(
      _textsOf(agent, ChatRole.error),
      isNot(contains('Detenido por el usuario.')),
    );
    expect(agent.queuedMessages, isEmpty);
    expect(agent.isStreaming, isFalse);
  }, skip: !isFakeRun);

  test('a message sent right after Stop in a claude chat is answered by a '
      'fresh process, not lost on the one being killed', () async {
    expect(
      await UserShellPath.locate('claude'),
      File('test/agents/fixtures/chat_cli/claude').absolute.path,
    );
    final logs = _freshLogs('claude');
    final viewModel = AgentsViewModel();
    await pumpEventQueue();
    viewModel.createAgent(
      'Claude chat',
      model: kDefaultClaudeModelAlias,
      fullFileSystemAccess: false,
      effort: 'medium',
    );
    final agentId = viewModel.data.agents.single.id;
    addTearDown(() => TaskRunner.closeLive(agentId));

    final firstTurn = viewModel.sendMessage(agentId, 'Implementa el cambio.');
    await _untilExists(File('${logs.path}/turn-waiting'));
    // Stop kills the live process, which dies on its own schedule: the next
    // message must not land on it meanwhile.
    viewModel.stopAgent(agentId);
    final nextTurn = viewModel.sendMessage(agentId, 'segundo pedido');
    await firstTurn.timeout(
      const Duration(seconds: 20),
      onTimeout: () => fail(
        'the stopped turn never ended: the next message took over the '
        'process being killed',
      ),
    );
    // The stopped turn is over; the new one is still being answered, and it
    // still owns the chat.
    expect(viewModel.data.agents.single.isStreaming, isTrue);
    await nextTurn.timeout(const Duration(seconds: 20), onTimeout: () {});

    final agent = viewModel.data.agents.single;
    expect(
      _textsOf(agent, ChatRole.assistant),
      contains('RESPUESTA: segundo pedido'),
    );
    expect(
      File('${logs.path}/invocations.log').readAsLinesSync(),
      hasLength(2),
    );
    expect(agent.isStreaming, isFalse);
  }, skip: !isFakeRun);

  // Non-regression only: a one-shot process starts slower than the stopped
  // one dies, so this path never showed the race the live tests cover.
  test(
    '«Enviar ahora» in a chat whose provider takes no mid-turn message still '
    'stops the turn and answers the message in the next one',
    () async {
      expect(
        await UserShellPath.locate('codex'),
        File('test/agents/fixtures/chat_cli/codex').absolute.path,
      );
      final logs = _freshLogs('codex');
      final viewModel = AgentsViewModel();
      await pumpEventQueue();
      viewModel.createAgent(
        'Codex chat',
        model: kCodexDefaultModelAlias,
        fullFileSystemAccess: false,
        effort: 'medium',
        provider: AgentProvider.codex,
      );
      final agentId = viewModel.data.agents.single.id;

      final firstTurn = viewModel.sendMessage(agentId, 'Implementa el cambio.');
      await _untilExists(File('${logs.path}/turn-waiting'));
      await viewModel.sendMessage(agentId, 'usa la otra descarga');
      final queued = viewModel.data.agents.single.queuedMessages.single;
      await viewModel.sendQueuedMessageNow(agentId, queued.id);
      await firstTurn.timeout(const Duration(seconds: 30));

      final agent = viewModel.data.agents.single;
      expect(
        _textsOf(agent, ChatRole.assistant),
        contains('RECIBIDO: usa la otra descarga'),
      );
      expect(agent.queuedMessages, isEmpty);
      expect(agent.isStreaming, isFalse);
    },
    skip: !isFakeRun,
  );
}

/// The fixture's log folder for [provider], emptied: its first process
/// behaves differently from the ones that replace it.
Directory _freshLogs(String provider) {
  final logs = Directory('${Platform.environment['KEEL_FAKE_DIR']}/$provider');
  if (logs.existsSync()) logs.deleteSync(recursive: true);
  return logs;
}

Future<void> _untilExists(File marker) async {
  final started = DateTime.now();
  while (!marker.existsSync()) {
    if (DateTime.now().difference(started) > const Duration(seconds: 20)) {
      fail('the turn never reached its tool');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

String _textsOf(Agent agent, ChatRole role) => agent.messages
    .where((message) => message.role == role)
    .map((message) => message.text)
    .join('\n');
