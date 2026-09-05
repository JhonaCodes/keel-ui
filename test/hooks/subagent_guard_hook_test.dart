import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/hook_delivery/hook_delivery.dart';
import 'package:keel_ui/src/modules/hooks/model/hook_event.dart';

void main() {
  group('subagent guard hook', () {
    test('claude recibe un PreToolUse sobre Task con el cupo en el script',
        () {
      final turn = prepareTurnHooks(
        catalog: const [],
        tools: const [],
        secretValues: const {},
        provider: HookProvider.claude,
        subagentCap: 2,
      );

      final settings =
          jsonDecode(turn.claudeSettings!) as Map<String, dynamic>;
      final pre = (settings['hooks'] as Map)['PreToolUse'] as List;
      final entry = pre.single as Map;
      expect(entry['matcher'], 'Task');
      expect(
        turn.files['$kSubagentGuardHookName.body.sh'],
        allOf(contains('permissionDecision'), contains('deny')),
      );
    });

    test('el script deja pasar el cupo y deniega la tarea de más', () async {
      // El oráculo es el shell real: el CLI ejecuta exactamente esto.
      final turn = prepareTurnHooks(
        catalog: const [],
        tools: const [],
        secretValues: const {},
        provider: HookProvider.claude,
        subagentCap: 2,
      );
      final dir = await Directory.systemTemp.createTemp('keel_guard_');
      addTearDown(() => dir.delete(recursive: true));
      for (final entry in turn.files.entries) {
        await File('${dir.path}/${entry.key}').writeAsString(entry.value);
      }
      final wrapper = '${dir.path}/$kSubagentGuardHookName.sh';

      Future<String> decision() async {
        final process = await Process.start('bash', [wrapper]);
        process.stdin.write('{"tool_name":"Task","tool_input":{}}');
        await process.stdin.close();
        final out = await process.stdout.transform(utf8.decoder).join();
        await process.exitCode;
        final line = out.trim().split('\n').lastWhere(
          (line) => line.trim().startsWith('{'),
          orElse: () => '{}',
        );
        final decoded = jsonDecode(line) as Map<String, dynamic>;
        return ((decoded['hookSpecificOutput'] as Map?)?['permissionDecision'] ??
                'allow')
            .toString();
      }

      expect(await decision(), 'allow');
      expect(await decision(), 'allow');
      expect(await decision(), 'deny');
      expect(await decision(), 'deny');
    });

    test('con cupo cero deniega desde la primera', () async {
      final turn = prepareTurnHooks(
        catalog: const [],
        tools: const [],
        secretValues: const {},
        provider: HookProvider.claude,
        subagentCap: 0,
      );
      expect(
        turn.files['$kSubagentGuardHookName.body.sh'],
        contains('deny'),
      );
    });

    test('sin cupo declarado no agrega el hook', () {
      final turn = prepareTurnHooks(
        catalog: const [],
        tools: const [],
        secretValues: const {},
        provider: HookProvider.claude,
      );
      expect(turn.isEmpty, isTrue);
    });
  });
}
