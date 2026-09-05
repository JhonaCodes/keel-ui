import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/hook_delivery/hook_delivery.dart';
import 'package:keel_ui/src/modules/hooks/model/hook_event.dart';

void main() {
  group('tool cap hook', () {
    test('codex recibe un PreToolUse sin matcher con el tope en el script',
        () {
      final turn = prepareTurnHooks(
        catalog: const [],
        tools: const [],
        secretValues: const {},
        provider: HookProvider.codex,
        toolCallCap: 6,
      );

      expect(turn.codexConfig, startsWith('hooks.PreToolUse=['));
      expect(turn.codexConfig, contains(kToolCapHookName));
      expect(turn.codexConfig, isNot(contains('matcher=')));
      expect(
        turn.files['$kToolCapHookName.body.sh'],
        allOf(contains('permissionDecision'), contains('deny'), contains('6')),
      );
    });

    test('el script deja pasar N llamadas y deniega la N+1 pidiendo el '
        'cierre', () async {
      final turn = prepareTurnHooks(
        catalog: const [],
        tools: const [],
        secretValues: const {},
        provider: HookProvider.codex,
        toolCallCap: 2,
      );
      final dir = await Directory.systemTemp.createTemp('keel_cap_');
      addTearDown(() => dir.delete(recursive: true));
      for (final entry in turn.files.entries) {
        await File('${dir.path}/${entry.key}').writeAsString(entry.value);
      }
      final wrapper = '${dir.path}/$kToolCapHookName.sh';

      Future<Map<String, dynamic>> decision() async {
        final process = await Process.start('bash', [wrapper]);
        process.stdin.write('{"tool_name":"Bash","tool_input":{}}');
        await process.stdin.close();
        final out = await process.stdout.transform(utf8.decoder).join();
        await process.exitCode;
        final line = out.trim().split('\n').lastWhere(
          (line) => line.trim().startsWith('{'),
          orElse: () => '{}',
        );
        final decoded = jsonDecode(line) as Map<String, dynamic>;
        return (decoded['hookSpecificOutput'] as Map).cast<String, dynamic>();
      }

      expect((await decision())['permissionDecision'], 'allow');
      expect((await decision())['permissionDecision'], 'allow');
      final third = await decision();
      expect(third['permissionDecision'], 'deny');
      expect(third['permissionDecisionReason'], contains('keel-outcome'));
    });
  });
}
