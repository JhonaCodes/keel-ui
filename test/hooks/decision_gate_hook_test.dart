import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/hook_delivery/hook_delivery.dart';
import 'package:keel_ui/src/modules/hooks/model/hook_event.dart';

void main() {
  const gate = DecisionGateSpec(
    url: 'http://127.0.0.1:4242/gate/p1/s1/pr1',
    token: 'secret-token',
  );

  group('decision gate hook', () {
    test('claude recibe un PreToolUse sobre las tools que escriben, con plazo '
        'largo y un script que devuelve permissionDecision', () {
      final turn = prepareTurnHooks(
        catalog: const [],
        tools: const [],
        secretValues: const {},
        provider: HookProvider.claude,
        gate: gate,
      );

      final settings =
          jsonDecode(turn.claudeSettings!) as Map<String, dynamic>;
      final pre = (settings['hooks'] as Map)['PreToolUse'] as List;
      final entry = pre.single as Map;
      final matcher = entry['matcher'] as String;
      expect(matcher, contains('Bash'));
      expect(matcher, contains('Edit'));
      expect(matcher, contains('Write'));
      final command = (entry['hooks'] as List).single as Map;
      expect(command['timeout'], greaterThanOrEqualTo(kDecisionGateTimeoutSeconds));
      expect(command['command'], contains(kDecisionGateHookName));

      final body = turn.files['$kDecisionGateHookName.body.sh']!;
      expect(body, contains('permissionDecision'));
      expect(body, contains(gate.url));
      expect(body, contains(gate.token));
    });

    test('codex recibe el mismo gate como override -c (0.153 ya no acepta '
        'perfil al reanudar)', () {
      final turn = prepareTurnHooks(
        catalog: const [],
        tools: const [],
        secretValues: const {},
        provider: HookProvider.codex,
        gate: gate,
      );

      expect(turn.codexConfig, startsWith('hooks.PreToolUse=['));
      expect(turn.codexConfig, isNot(contains('[[hooks.PreToolUse]]')));
      expect(turn.codexConfig, contains(kDecisionGateHookName));
      expect(turn.files.keys, contains('$kDecisionGateHookName.sh'));
    });

    test('sin gate y sin catálogo no hay hooks, como antes', () {
      final turn = prepareTurnHooks(
        catalog: const [],
        tools: const [],
        secretValues: const {},
        provider: HookProvider.claude,
      );

      expect(turn.isEmpty, isTrue);
      expect(turn.claudeSettings, isNull);
    });
  });
}
