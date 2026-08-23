import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/llm/llm.dart';
import 'package:keel_ui/src/integrations/llm/src/llm_dispatcher.dart';
import 'package:keel_ui/src/integrations/llm/codex/codex_cli_runner.dart';
import 'package:keel_ui/src/integrations/llm/claude/claude_cli_runner.dart';

void main() {
  group('dispatchLlmProvider', () {
    test('Codex(CodexCli()) despacha a CodexCliRunner', () {
      final runner = dispatchLlmProvider(const Codex(CodexCli()));

      expect(runner, isA<CodexCliRunner>());
    });

    test('Claude(ClaudeCli()) despacha a ClaudeCliRunner', () {
      final runner = dispatchLlmProvider(const Claude(ClaudeCli()));

      expect(runner, isA<ClaudeCliRunner>());
    });

    test('el alias legacy también llega a un runner via el mapeo', () {
      final fromCodexAlias = dispatchLlmProvider(
        LlmProvider.fromLegacyAlias('codex'),
      );
      final fromClaudeAlias = dispatchLlmProvider(
        LlmProvider.fromLegacyAlias('claude'),
      );

      expect(fromCodexAlias, isA<CodexCliRunner>());
      expect(fromClaudeAlias, isA<ClaudeCliRunner>());
    });
  });
}
