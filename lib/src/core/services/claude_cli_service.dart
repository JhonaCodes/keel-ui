import 'dart:convert';
import 'dart:io';

import 'package:keel_ui/src/core/services/cli_turn_workspace.dart';
import 'package:keel_ui/src/core/services/turn_usage.dart';

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

  /// Los contadores del turno. Se leían para calcular el porcentaje de
  /// contexto y se tiraban; ahora viajan enteros para que el ledger pueda
  /// guardarlos. Sin esto no hay historial posible: el dato no existe en
  /// ningún otro lado.
  final String model;
  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheCreationTokens;

  const ClaudeTurnCompleted({
    required this.isError,
    required this.costUsd,
    required this.durationMs,
    this.model = '',
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cacheReadTokens = 0,
    this.cacheCreationTokens = 0,
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
/// 1:1, proyecto o asistente. Públicos por la misma razón que
/// [kAlwaysAllowedTools]: el isolate del task runner los necesita y dos
/// copias divergiendo en silencio es exactamente lo que no puede pasar.
/// En español, como el resto del corpus: abrían en inglés un prompt que
/// después habla todo en castellano.
const kCliSystemHints =
    '$_diagramSystemPromptHint\n\n$_codeEditSystemPromptHint';

/// Tools every agent gets, no setting required. They are all read-only or
/// network reads: an agent that cannot open a file is blind, and the whole
/// point of a project is that its agents look at the real code before they
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
    String? hooksSettings,
    Map<String, String> hookFiles = const {},
    void Function(Process process)? onProcessStarted,
  }) async* {
    final allowedTools = [...kAlwaysAllowedTools, ...extraAllowedTools];
    final systemPrompt =
        (additionalSystemPrompt == null || additionalSystemPrompt.isEmpty)
        ? kCliSystemHints
        : '$kCliSystemHints\n\n$additionalSystemPrompt';

    // Config y scripts viajan como ARCHIVOS, nunca inline: llevan valores
    // de secrets resueltos —los de los MCP externos y los que declara un
    // hook— y un argumento de línea de comandos es legible con `ps`. El
    // temporal es 0700 y se borra al terminar el turno.
    final workspace = await CliTurnWorkspace.create(
      mcpConfig: mcpConfig,
      claudeSettings: hooksSettings,
      hookFiles: hookFiles,
    );
    final mcpConfigPath = workspace.mcpConfigPath;

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
        // Los hooks administrados por keel-ui. `--settings` SUMA: lo que el
        // usuario tenga en su `~/.claude/settings.json` sigue valiendo, y
        // esta app no lo toca.
        if (workspace.claudeSettingsPath != null) ...[
          '--settings',
          workspace.claudeSettingsPath!,
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
      await workspace.dispose();
    }
  }

  /// El bloqueo de un hook, si este resultado de herramienta lo es.
  ///
  /// Se reconoce por la marca que dejan los wrappers de keel-ui, así que
  /// solo dispara con NUESTROS hooks: un hook que el usuario tenga en su
  /// propia configuración no la lleva, y un error común de herramienta
  /// tampoco.
  List<ClaudeEvent> _parseHookBlock(Map<String, dynamic> event) {
    final content =
        (event['message'] as Map<String, dynamic>?)?['content'] as List?;
    if (content == null) return const [];

    for (final part in content) {
      if (part is! Map || part['type'] != 'tool_result') continue;
      final text = part['content'] is String
          ? part['content'] as String
          : jsonEncode(part['content']);
      if (!text.contains(kHookDenialMarker)) continue;

      final tool = RegExp(r'PreToolUse:(\w+)').firstMatch(text)?.group(1);
      return [
        ClaudePermissionDenied(
          toolName: tool ?? 'la herramienta',
          message: text,
        ),
      ];
    }
    return const [];
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

      // Un hook que bloquea NO llega como `permission_denied`: llega como
      // el resultado con error de la herramienta que frenó. Verificado
      // contra el CLI real. Sin este caso, el bloqueo solo lo contaría el
      // modelo en prosa y la app no tendría cómo decir cuál hook fue.
      case 'user':
        return _parseHookBlock(event);

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
        final usage = readTurnUsage(event);
        return [
          ClaudeTurnCompleted(
            isError: event['is_error'] as bool,
            costUsd: usage.costUsd,
            durationMs: usage.durationMs,
            model: usage.model,
            inputTokens: usage.inputTokens,
            outputTokens: usage.outputTokens,
            cacheReadTokens: usage.cacheReadTokens,
            cacheCreationTokens: usage.cacheCreationTokens,
          ),
          if (usage.contextWindowTokens > 0)
            ClaudeContextUsage(
              usedTokens: usedContextOf(usage),
              contextWindowTokens: usage.contextWindowTokens,
            ),
        ];

      default:
        return const [];
    }
  }
}
