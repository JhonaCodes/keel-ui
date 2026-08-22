import 'dart:convert';
import 'dart:io';

import 'package:logger_rs/logger_rs.dart';

sealed class ClaudeEvent {
  const ClaudeEvent();
}

class ClaudeSessionStarted extends ClaudeEvent {
  final String sessionId;
  const ClaudeSessionStarted(this.sessionId);
}

class ClaudeAssistantText extends ClaudeEvent {
  final String text;
  const ClaudeAssistantText(this.text);
}

class ClaudeToolUse extends ClaudeEvent {
  final String name;
  final Map<String, dynamic>? input;
  const ClaudeToolUse(this.name, this.input);
}

class ClaudeReasoningChunk extends ClaudeEvent {
  final String text;
  const ClaudeReasoningChunk(this.text);
}

class ClaudePermissionDenied extends ClaudeEvent {
  final String toolName;
  final String message;
  const ClaudePermissionDenied({required this.toolName, required this.message});
}

class ClaudeTurnCompleted extends ClaudeEvent {
  final bool isError;
  final double costUsd;
  final int durationMs;
  const ClaudeTurnCompleted({
    required this.isError,
    required this.costUsd,
    required this.durationMs,
  });
}

class ClaudeFailure extends ClaudeEvent {
  final String message;
  const ClaudeFailure(this.message);
}

class ClaudeContextUsage extends ClaudeEvent {
  final int usedTokens;
  final int contextWindowTokens;
  const ClaudeContextUsage({
    required this.usedTokens,
    required this.contextWindowTokens,
  });
}

const _diagramSystemPromptHint =
    'Para mostrar un diagrama, una jerarquía, una línea de tiempo o un '
    'flujo, preferí un bloque ```mermaid antes que SVG crudo: cuesta muchos '
    'menos tokens y en este cliente se ve igual de bien. Caé a ```svg solo '
    'cuando mermaid no pueda expresar la forma (ilustraciones precisas a '
    'medida).';

const _codeEditSystemPromptHint =
    'Cuando el mensaje ES un pedido de cambiar código de un archivo real '
    'del disco —escribir, corregir, convertir, refactorizar—, hacé el '
    'cambio con tus herramientas de archivo (Write/Edit) en vez de imprimir '
    'el código en la respuesta: este cliente muestra la edición real como '
    'una tarjeta de diff que el usuario revisa, ajusta y guarda. Imprimí '
    'código inline solo cuando te piden VER o discutir un fragmento. Y si '
    'el mensaje era una pregunta y no un pedido, esta regla no aplica: '
    'primero respondé.';

/// Los dos consejos que encabezan el system prompt de TODO turno claude —
/// 1:1, estación o asistente. Públicos por la misma razón que
/// [kAlwaysAllowedTools]: el isolate del task runner los necesita y dos
/// copias divergiendo en silencio es exactamente lo que no puede pasar.
/// En español, como el resto del corpus: abrían en inglés un prompt que
/// después habla todo en castellano.
const kCliSystemHints =
    '$_diagramSystemPromptHint\n\n$_codeEditSystemPromptHint';

/// Tools every agent gets, no setting required. They are all read-only or
/// network reads: an agent that cannot open a file is blind, and the whole
/// point of a station is that its agents look at the real code before they
/// say anything about it. Anything that *writes* stays opt-in — see
/// `kAvailableExtraTools`.
const kAlwaysAllowedTools = <String>[
  'Read',
  'Glob',
  'Grep',
  'WebFetch',
  'WebSearch',
];

/// Drives the local `claude` CLI (Claude Code) as a subprocess — never the
/// hosted API. One call = one turn of an agent's conversation, optionally
/// resumed by [sessionId].
class ClaudeCliService {
  Stream<ClaudeEvent> run({
    required String prompt,
    required String workingDirectory,
    required String model,
    required bool fullFileSystemAccess,
    required String effort,
    List<String> extraAllowedTools = const [],
    String? sessionId,
    String? additionalSystemPrompt,
    String? mcpConfig,
    void Function(Process process)? onProcessStarted,
  }) async* {
    final allowedTools = [...kAlwaysAllowedTools, ...extraAllowedTools];
    final systemPrompt =
        (additionalSystemPrompt == null || additionalSystemPrompt.isEmpty)
        ? kCliSystemHints
        : '$kCliSystemHints\n\n$additionalSystemPrompt';

    // The MCP config travels as a FILE, never inline: the JSON may embed
    // resolved secret values (external MCP servers' env), and an inline
    // argument is world-readable via `ps`. The temp dir from createTemp is
    // 0700, so only this user can read it; removed after the turn.
    Directory? mcpConfigDir;
    String? mcpConfigPath;
    if (mcpConfig != null) {
      mcpConfigDir = await Directory.systemTemp.createTemp('keel_mcpcfg_');
      final file = File('${mcpConfigDir.path}/mcp.json');
      await file.writeAsString(mcpConfig);
      mcpConfigPath = file.path;
    }

    try {
      final arguments = [
        '-p',
        prompt,
        '--output-format',
        'stream-json',
        '--verbose',
        '--model',
        model,
        '--effort',
        effort,
        '--allowedTools',
        allowedTools.join(','),
        '--append-system-prompt',
        systemPrompt,
        if (mcpConfigPath != null) ...[
          '--mcp-config',
          mcpConfigPath,
          '--strict-mcp-config',
        ],
        if (fullFileSystemAccess) ...['--add-dir', '/'],
        if (sessionId != null) ...['--resume', sessionId],
      ];

      Process process;
      try {
        process = await Process.start(
          'claude',
          arguments,
          workingDirectory: workingDirectory,
          runInShell: true,
        );
      } catch (error) {
        Log.e('Failed to start claude CLI', error: error);
        yield ClaudeFailure('No se pudo iniciar claude: $error');
        return;
      }
      onProcessStarted?.call(process);

      final stderrBuffer = StringBuffer();
      final stderrDone = process.stderr
          .transform(utf8.decoder)
          .forEach(stderrBuffer.write);

      final lines = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lines) {
        if (line.trim().isEmpty) continue;

        Map<String, dynamic> event;
        try {
          event = jsonDecode(line) as Map<String, dynamic>;
        } catch (error) {
          Log.w('Unparseable claude output line: $line');
          continue;
        }

        for (final parsed in _parseEvent(event)) {
          yield parsed;
        }
      }

      await stderrDone;
      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        final stderrText = stderrBuffer.toString().trim();
        yield ClaudeFailure(
          stderrText.isEmpty
              ? 'claude terminó con código $exitCode'
              : stderrText,
        );
      }
    } finally {
      if (mcpConfigDir != null) {
        try {
          await mcpConfigDir.delete(recursive: true);
        } catch (error) {
          Log.w('Could not clean up ${mcpConfigDir.path}: $error');
        }
      }
    }
  }

  List<ClaudeEvent> _parseEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    switch (type) {
      case 'system':
        return switch (event['subtype']) {
          'init' => switch (event['session_id'] as String?) {
            null => const <ClaudeEvent>[],
            final sessionId => [ClaudeSessionStarted(sessionId)],
          },
          'permission_denied' => [
            ClaudePermissionDenied(
              toolName: event['tool_name'] as String? ?? 'desconocido',
              message: event['message'] as String? ?? 'Permiso denegado.',
            ),
          ],
          _ => const <ClaudeEvent>[],
        };

      case 'assistant':
        final message = event['message'] as Map<String, dynamic>?;
        final content = message?['content'] as List<dynamic>?;
        if (content == null) return const [];

        final events = <ClaudeEvent>[];
        final textBuffer = StringBuffer();
        for (final block in content.whereType<Map<String, dynamic>>()) {
          switch (block['type']) {
            case 'thinking':
              final thinking = block['thinking'] as String?;
              if (thinking != null && thinking.isNotEmpty) {
                events.add(ClaudeReasoningChunk(thinking));
              }
            case 'text':
              textBuffer.write(block['text'] as String? ?? '');
            case 'tool_use':
              final name = block['name'] as String?;
              if (name != null) {
                events.add(
                  ClaudeToolUse(name, block['input'] as Map<String, dynamic>?),
                );
              }
          }
        }
        final text = textBuffer.toString();
        if (text.isNotEmpty) events.add(ClaudeAssistantText(text));
        return events;

      case 'result':
        final events = <ClaudeEvent>[
          ClaudeTurnCompleted(
            isError: event['is_error'] as bool,
            costUsd: (event['total_cost_usd'] as num?)?.toDouble() ?? 0,
            durationMs: event['duration_ms'] as int? ?? 0,
          ),
        ];

        final usage = event['usage'] as Map<String, dynamic>?;
        final modelUsage = event['modelUsage'] as Map<String, dynamic>?;
        final mainModel = _mainModelUsageEntry(modelUsage);
        final contextWindow = mainModel?['contextWindow'] as int?;
        if (usage != null && contextWindow != null) {
          final usedTokens =
              (usage['input_tokens'] as num? ?? 0).toInt() +
              (usage['cache_creation_input_tokens'] as num? ?? 0).toInt() +
              (usage['cache_read_input_tokens'] as num? ?? 0).toInt();
          events.add(
            ClaudeContextUsage(
              usedTokens: usedTokens,
              contextWindowTokens: contextWindow,
            ),
          );
        }
        return events;

      default:
        return const [];
    }
  }

  /// Picks the modelUsage entry with the largest total usage — that's the
  /// model actually driving this conversation, as opposed to small internal
  /// side-calls (e.g. a background haiku call) that also appear in the map.
  Map<String, dynamic>? _mainModelUsageEntry(Map<String, dynamic>? modelUsage) {
    if (modelUsage == null) return null;

    Map<String, dynamic>? best;
    var bestTotal = -1;
    for (final value in modelUsage.values) {
      final entry = value as Map<String, dynamic>;
      final total =
          (entry['inputTokens'] as num? ?? 0).toInt() +
          (entry['cacheReadInputTokens'] as num? ?? 0).toInt() +
          (entry['cacheCreationInputTokens'] as num? ?? 0).toInt();
      if (total > bestTotal) {
        bestTotal = total;
        best = entry;
      }
    }
    return best;
  }
}
