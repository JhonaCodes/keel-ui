import 'package:keel_ui/src/integrations/llm/claude/claude_cli_runner.dart';
import 'package:keel_ui/src/integrations/llm/claude/claude_live_session.dart';
import 'package:keel_ui/src/integrations/llm/codex/codex_cli_runner.dart';
import 'package:keel_ui/src/integrations/llm/llm.dart';
import 'package:keel_ui/src/integrations/llm/openai_compatible/openai_compatible_api_runner.dart';
import 'package:keel_ui/src/integrations/llm/opencode/opencode_runner.dart';
import 'package:keel_ui/src/integrations/llm/opencode/opencode_serve_session.dart';

/// El único lugar que traduce un [LlmProvider] al [LlmRunner] concreto. Sin
/// `default` ni `_`: agregar un target sin su rama acá no compila — ver
/// invariantes-llm-providers, regla 2.
LlmRunner dispatchLlmProvider(LlmProvider provider, {String? providerApiKey}) =>
    switch (provider) {
      Codex(target: CodexCli()) => const CodexCliRunner(),
      Claude(target: ClaudeCli()) => const ClaudeCliRunner(),
      OpenCode(target: OpenCodeServe()) => const OpenCodeRunner(),
      OpenAiCompatible(
        target: OpenAiCompatibleApi(
          :final baseUrl,
          :final secretRef,
          :final dialect,
        ),
      ) =>
        OpenAiCompatibleApiRunner(
          baseUrl: baseUrl,
          secretRef: secretRef,
          dialect: dialect,
          apiKey: providerApiKey,
        ),
    };

/// Starts a provider process that stays alive across turns.
typedef LlmLiveSessionStarter =
    Future<LlmLiveSession> Function(
      LlmTurnSpec spec, {
      required String userPath,
      void Function(int pid)? onPidKnown,
    });

/// The live-session starter of a target, or null when it has none. Same rule
/// as [dispatchLlmProvider]: no `default`, so a new target has to say here
/// whether it can keep one process per conversation.
LlmLiveSessionStarter? dispatchLlmLiveSession(LlmProvider provider) =>
    switch (provider) {
      Claude(target: ClaudeCli()) => ClaudeLiveSession.start,
      // One server per conversation: MCP config is per server instance.
      OpenCode(target: OpenCodeServe()) => OpenCodeServeSession.start,
      // `codex exec` takes one prompt per process and has no stdin protocol.
      Codex(target: CodexCli()) => null,
      // An HTTP API has no process to keep warm: every request is the turn.
      OpenAiCompatible(target: OpenAiCompatibleApi()) => null,
    };
