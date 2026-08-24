import 'package:keel_ui/src/integrations/llm/claude/claude_cli_runner.dart';
import 'package:keel_ui/src/integrations/llm/codex/codex_cli_runner.dart';
import 'package:keel_ui/src/integrations/llm/llm.dart';
import 'package:keel_ui/src/integrations/llm/openai_compatible/openai_compatible_api_runner.dart';

/// El único lugar que traduce un [LlmProvider] al [LlmRunner] concreto. Sin
/// `default` ni `_`: agregar un target sin su rama acá no compila — ver
/// invariantes-llm-providers, regla 2.
LlmRunner dispatchLlmProvider(LlmProvider provider, {String? providerApiKey}) =>
    switch (provider) {
      Codex(target: CodexCli()) => const CodexCliRunner(),
      Claude(target: ClaudeCli()) => const ClaudeCliRunner(),
      OpenAiCompatible(
        target: OpenAiCompatibleApi(:final baseUrl, :final secretRef),
      ) =>
        OpenAiCompatibleApiRunner(
          baseUrl: baseUrl,
          secretRef: secretRef,
          apiKey: providerApiKey,
        ),
    };
