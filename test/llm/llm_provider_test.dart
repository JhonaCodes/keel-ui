import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/llm/llm.dart';

void main() {
  group('LlmProvider.fromLegacyAlias', () {
    test('codex mapea a Codex(CodexCli())', () {
      final provider = LlmProvider.fromLegacyAlias('codex');

      expect(provider, isA<Codex>());
      expect((provider as Codex).target, isA<CodexCli>());
    });

    test('claude mapea a Claude(ClaudeCli())', () {
      final provider = LlmProvider.fromLegacyAlias('claude');

      expect(provider, isA<Claude>());
      expect((provider as Claude).target, isA<ClaudeCli>());
    });

    test('un alias desconocido lanza ArgumentError', () {
      expect(
        () => LlmProvider.fromLegacyAlias('gemini'),
        throwsArgumentError,
      );
    });
  });
}
