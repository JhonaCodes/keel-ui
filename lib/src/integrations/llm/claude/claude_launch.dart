import 'dart:io';

import 'package:keel_ui/src/core/services/cli_turn_contract.dart';
import 'package:keel_ui/src/core/services/cli_turn_workspace.dart';
import 'package:keel_ui/src/integrations/llm/llm.dart';
import 'package:keel_ui/src/integrations/system_prompt/system_prompt.dart';

/// What a `claude` process needs before it starts, the same for a one-shot
/// turn and for a live session: the 0700 temp workspace (MCP config, hook
/// settings) and the system prompt with the CLI hints in front.
class ClaudeLaunch {
  const ClaudeLaunch._({
    required this.workspace,
    required this.allowedTools,
    required this.systemPrompt,
  });

  /// Files, never inline arguments: an argument is readable with `ps`. It
  /// lives exactly as long as the process that reads it.
  final CliTurnWorkspace workspace;
  final List<String> allowedTools;
  final String systemPrompt;

  static Future<ClaudeLaunch> prepare(LlmTurnSpec spec) async {
    final additionalPrompt = spec.additionalSystemPrompt;
    return ClaudeLaunch._(
      workspace: await CliTurnWorkspace.create(
        mcpConfig: spec.mcpConfig,
        claudeSettings: spec.hooksSettings,
        hookFiles: spec.hookFiles,
      ),
      allowedTools: [...kAlwaysAllowedTools, ...spec.extraAllowedTools],
      systemPrompt: (additionalPrompt == null || additionalPrompt.isEmpty)
          ? kCliSystemHints
          : '$kCliSystemHints\n\n$additionalPrompt',
    );
  }

  /// Starts `claude` with the user's PATH — the inherited one is launchd's,
  /// not the terminal's — and with the MCP tool deadline lifted: one of our
  /// tools waits for the person to approve a blocked change, and the CLI's
  /// default would drop it. See [kMcpToolTimeoutMillis].
  static Future<Process> start(
    List<String> arguments, {
    required String workingDirectory,
    required String userPath,
  }) => Process.start(
    'claude',
    arguments,
    workingDirectory: workingDirectory,
    environment: {
      'PATH': userPath,
      'MCP_TOOL_TIMEOUT': '$kMcpToolTimeoutMillis',
    },
    runInShell: true,
  );
}
