import 'dart:convert';
import 'dart:io';

import 'package:keel_ui/src/core/services/cli_turn_workspace.dart';

import 'package:logger_rs/logger_rs.dart';

import 'package:keel_ui/src/core/services/claude_cli_service.dart';
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart';

/// Drives the local `codex` CLI (OpenAI Codex) as a subprocess, emitting the
/// SAME [ClaudeEvent] stream the claude adapter emits so every consumer
/// (1:1 chat, stations) stays provider-agnostic.
///
/// Verified against `codex-cli 0.142.3` (`codex exec --json`): events are
/// JSONL of the `thread.started` / `turn.*` / `item.*` family. Known
/// differences vs claude, all absorbed here:
/// - No system-prompt flag exists → the profile prompt is PREPENDED to the
///   first turn's user prompt as a delimited preamble (resumed turns keep it
///   from the thread history).
/// - No effort levels, no `--allowedTools`, no MCP config per turn (codex
///   MCP lives in its own TOML config) → those inputs simply don't exist in
///   this adapter's signature.
/// - `model` IS forwarded as `-m`, but only when it is a codex model: the
///   catalogs are per provider now (`agent_model_option.dart`), and an
///   empty alias — or a leftover Claude one — means "let codex resolve it
///   from `~/.codex/config.toml`".
/// - Sandbox mapping: full access → `danger-full-access`, otherwise
///   `workspace-write`.
class CodexCliService {
  Stream<ClaudeEvent> run({
    required String prompt,
    required String workingDirectory,
    required bool fullFileSystemAccess,
    String model = kCodexDefaultModelAlias,
    String? sessionId,
    String? additionalSystemPrompt,
    String? hooksConfig,
    Map<String, String> hookFiles = const {},
    void Function(Process process)? onProcessStarted,
  }) async* {
    final effectivePrompt =
        (sessionId == null &&
            additionalSystemPrompt != null &&
            additionalSystemPrompt.isNotEmpty)
        ? '### Instrucciones de tu rol (fijas para toda la conversación)\n'
              '$additionalSystemPrompt\n'
              '### Fin de instrucciones\n\n'
              '$prompt'
        : prompt;

    // Null when the agent carries no model, or a Claude alias left over from
    // before the model catalogs were split per provider: codex would reject
    // `-m sonnet`, so it falls back to the model in the user's codex config.
    final modelArgument = codexModelArgument(model);

    // Los hooks van como PERFIL, no metidos en `~/.codex/config.toml`: el
    // perfil se capa encima de la config del usuario, vale solo para esta
    // invocación y se borra al terminar. La config de codex es del usuario y
    // esta app no la edita.
    final workspace = await CliTurnWorkspace.create(
      codexHooksConfig: hooksConfig,
      hookFiles: hookFiles,
    );

    final arguments = [
      'exec',
      if (sessionId != null) ...['resume', sessionId],
      if (modelArgument != null) ...['-m', modelArgument],
      if (workspace.codexProfileName != null) ...[
        '-p',
        workspace.codexProfileName!,
      ],
      '--json',
      '--skip-git-repo-check',
      '-s',
      fullFileSystemAccess ? 'danger-full-access' : 'workspace-write',
      '--color',
      'never',
      effectivePrompt,
    ];

    Process process;
    try {
      process = await Process.start(
        'codex',
        arguments,
        workingDirectory: workingDirectory,
        runInShell: true,
      );
    } catch (error) {
      Log.e('Failed to start codex CLI', error: error);
      await workspace.dispose();
      yield ClaudeFailure('No se pudo iniciar codex: $error');
      return;
    }
    onProcessStarted?.call(process);

    // codex reads stdin when it isn't a TTY ("Reading additional input from
    // stdin...", observed in the real probe) — without an explicit close it
    // waits for EOF forever.
    try {
      await process.stdin.close();

      final stderrBuffer = StringBuffer();
      final stderrDone = process.stderr
          .transform(utf8.decoder)
          .forEach(stderrBuffer.write);

      final lines = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      var sawError = false;
      await for (final line in lines) {
        if (line.trim().isEmpty) continue;

        Map<String, dynamic> event;
        try {
          event = jsonDecode(line) as Map<String, dynamic>;
        } catch (_) {
          Log.w('Unparseable codex output line: $line');
          continue;
        }

        for (final parsed in _parseEvent(event)) {
          if (parsed is ClaudeFailure) sawError = true;
          yield parsed;
        }
      }

      await stderrDone;
      final exitCode = await process.exitCode;
      // codex exits 0 even on in-band errors (verified: out-of-credits run) —
      // those already surfaced as ClaudeFailure above.
      if (exitCode != 0 && !sawError) {
        final stderrText = stderrBuffer.toString().trim();
        yield ClaudeFailure(
          stderrText.isEmpty
              ? 'codex terminó con código $exitCode'
              : stderrText,
        );
      }
    } finally {
      await workspace.dispose();
    }
  }

  List<ClaudeEvent> _parseEvent(Map<String, dynamic> event) {
    switch (event['type'] as String?) {
      case 'thread.started':
        return switch (event['thread_id'] as String?) {
          null => const [],
          final threadId => [ClaudeSessionStarted(threadId)],
        };

      case 'item.completed':
      case 'item.updated':
      case 'item.started':
        final item = event['item'] as Map<String, dynamic>?;
        if (item == null) return const [];
        final isCompleted = event['type'] == 'item.completed';

        switch (item['type'] as String?) {
          case 'agent_message':
            // Only the completed form — earlier phases would duplicate text.
            final text = item['text'] as String?;
            return (isCompleted && text != null && text.isNotEmpty)
                ? [ClaudeAssistantText(text)]
                : const [];
          case 'reasoning':
            final text = item['text'] as String?;
            return (isCompleted && text != null && text.isNotEmpty)
                ? [ClaudeReasoningChunk(text)]
                : const [];
          case 'command_execution':
            final command = item['command'] as String?;
            return (!isCompleted && command != null)
                ? [
                    ClaudeToolUse('Bash', {'command': command}),
                  ]
                : const [];
          case 'file_change':
            return isCompleted
                ? const []
                : [const ClaudeToolUse('Edit', null)];
          case 'mcp_tool_call':
            final name = item['tool'] as String? ?? 'mcp';
            return isCompleted ? const [] : [ClaudeToolUse(name, null)];
          case 'web_search':
            return isCompleted
                ? const []
                : [const ClaudeToolUse('WebSearch', null)];
          default:
            return const [];
        }

      case 'turn.completed':
        return const [
          ClaudeTurnCompleted(isError: false, costUsd: 0, durationMs: 0),
        ];

      case 'turn.failed':
        final message =
            (event['error'] as Map<String, dynamic>?)?['message'] as String?;
        return [
          if (message != null) ClaudeFailure(message),
          const ClaudeTurnCompleted(isError: true, costUsd: 0, durationMs: 0),
        ];

      case 'error':
        return switch (event['message'] as String?) {
          null => const [],
          final message => [ClaudeFailure(message)],
        };

      default:
        return const [];
    }
  }
}
