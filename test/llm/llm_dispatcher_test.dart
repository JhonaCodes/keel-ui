import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/llm/claude/claude_cli_runner.dart';
import 'package:keel_ui/src/integrations/llm/codex/codex_cli_runner.dart';
import 'package:keel_ui/src/integrations/llm/llm.dart';
import 'package:keel_ui/src/integrations/llm/openai_compatible/openai_compatible_api_runner.dart';
import 'package:keel_ui/src/integrations/llm/src/llm_dispatcher.dart';

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

    test('OpenAiCompatible(OpenAiCompatibleApi()) despacha al runner API', () {
      final runner = dispatchLlmProvider(
        const OpenAiCompatible(
          OpenAiCompatibleApi(
            baseUrl: 'https://openrouter.ai/api/v1',
            secretRef: 'OPENROUTER_API_KEY',
          ),
        ),
      );

      expect(runner, isA<OpenAiCompatibleApiRunner>());
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
