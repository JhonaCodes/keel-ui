import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/cli_turn_contract.dart';
import 'package:keel_ui/src/integrations/hook_delivery/hook_delivery.dart';
import 'package:keel_ui/src/modules/hooks/model/hook_event.dart';

void main() {
  test(
    'at most 4 subagents run at once; one ending frees its place',
    () async {
      final turn = prepareTurnHooks(
        catalog: const [],
        tools: const [],
        secretValues: const {},
        provider: HookProvider.claude,
        parallelSubagentCap: SubagentLimits.maxParallel,
      );
      final settings = jsonDecode(turn.claudeSettings!) as Map;
      expect((settings['hooks'] as Map).keys, containsAll(['PreToolUse', 'SubagentStop']));

      final dir = await Directory.systemTemp.createTemp('keel_parallel_');
      addTearDown(() => dir.delete(recursive: true));
      for (final entry in turn.files.entries) {
        await File('${dir.path}/${entry.key}').writeAsString(entry.value);
      }

      Future<String?> run(String hookName, String event) async {
        final process = await Process.start('bash', [
          '${dir.path}/$hookName.sh',
        ]);
        process.stdin.write(
          jsonEncode({'hook_event_name': event, 'tool_name': 'Agent'}),
        );
        await process.stdin.close();
        final out = await process.stdout.transform(utf8.decoder).join();
        await process.exitCode;
        final line = out.trim().split('\n').lastWhere(
          (line) => line.trim().startsWith('{'),
          orElse: () => '',
        );
        if (line.isEmpty) return null;
        return ((jsonDecode(line) as Map)['hookSpecificOutput']
                as Map)['permissionDecision']
            as String?;
      }

      Future<String?> launch() =>
          run(SubagentParallelGuard.startHookName, 'PreToolUse');

      // Four launched in the same instant all fit.
      final first = await Future.wait([for (var i = 0; i < 4; i++) launch()]);
      expect(first, everyElement(isNot('deny')));
      expect(await launch(), 'deny');

      await run(SubagentParallelGuard.stopHookName, 'SubagentStop');
      expect(await launch(), isNot('deny'));
      expect(await launch(), 'deny');
    },
  );
}
