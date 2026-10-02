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

/// Whether a target takes a user message in the middle of a turn without
/// stopping it. Same rule as [dispatchLlmProvider]: no `default`, so a new
/// target has to say here whether it can. Where it cannot, sending a message
/// "now" still means cutting the turn and resuming the node.
bool dispatchLlmSteering(LlmProvider provider) => switch (provider) {
  // stream-json on stdin: a user line written mid-turn enters at the next
  // tool boundary (verified against CLI 2.1.280).
  Claude(target: ClaudeCli()) => true,
  // `codex exec` reads one prompt and has no stdin protocol.
  Codex(target: CodexCli()) => false,
  // Each turn is one request to the serve session.
  OpenCode(target: OpenCodeServe()) => false,
  // An HTTP request takes no more input once it is sent.
  OpenAiCompatible(target: OpenAiCompatibleApi()) => false,
};
