import 'dart:convert';
import 'dart:io';

import 'package:keel_ui/src/core/services/claude_stream_events.dart';
import 'package:keel_ui/src/core/services/cli_turn_workspace.dart';

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

/// Un `Task` que abrió un subagente. [id] es el `tool_use_id` con el que ese
/// subagente va a hablar el resto del turno, y es lo que lo vuelve un nodo con
/// nombre en vez de la frase «delegando tarea a un subagente».
class ClaudeSubagentStarted extends ClaudeEvent {
  final String id;
  final String agentType;
  final String ask;
  final String prompt;
  const ClaudeSubagentStarted({
    required this.id,
    required this.agentType,
    required this.ask,
    required this.prompt,
  });
}

class ClaudeSubagentText extends ClaudeEvent {
  final String id;
  final String text;
  const ClaudeSubagentText(this.id, this.text);
}

class ClaudeSubagentReasoning extends ClaudeEvent {
  final String id;
  final String text;
  const ClaudeSubagentReasoning(this.id, this.text);
}

class ClaudeSubagentToolUse extends ClaudeEvent {
  final String id;
  final String name;
  final Map<String, dynamic>? input;
  const ClaudeSubagentToolUse(this.id, this.name, this.input);
}

class ClaudeSubagentFinished extends ClaudeEvent {
  final String id;
  final String result;
  final bool isError;
  const ClaudeSubagentFinished({
    required this.id,
    required this.result,
    required this.isError,
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
        // Sin esto el texto y el pensamiento de un subagente llegan mezclados
        // con los del padre y quedan firmados por alguien que no los escribió.
        '--forward-subagent-text',
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

      final reader = ClaudeStreamReader();
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

        for (final message in reader.read(event)) {
          yield _eventFrom(message);
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

  /// El formato de cable del lector, tipado.
  ///
  /// El lector devuelve mapas porque es lo único que cruza un puerto de
  /// isolate y el runner de tareas lo manda tal cual; acá, que no cruza nada,
  /// se convierte al tipo de una vez.
  ClaudeEvent _eventFrom(Map<String, dynamic> message) {
    return switch (message['type']) {
      'sessionStarted' => ClaudeSessionStarted(message['sessionId'] as String),
      'assistantText' => ClaudeAssistantText(message['text'] as String),
      'reasoningChunk' => ClaudeReasoningChunk(message['text'] as String),
      'toolUse' => ClaudeToolUse(
        message['name'] as String,
        (message['input'] as Map?)?.cast<String, dynamic>(),
      ),
      'permissionDenied' => ClaudePermissionDenied(
        toolName: message['toolName'] as String,
        message: message['message'] as String,
      ),
      'subagentStarted' => ClaudeSubagentStarted(
        id: message['id'] as String,
        agentType: message['agentType'] as String,
        ask: message['ask'] as String,
        prompt: message['prompt'] as String,
      ),
      'subagentText' => ClaudeSubagentText(
        message['id'] as String,
        message['text'] as String,
      ),
      'subagentReasoning' => ClaudeSubagentReasoning(
        message['id'] as String,
        message['text'] as String,
      ),
      'subagentToolUse' => ClaudeSubagentToolUse(
        message['id'] as String,
        message['name'] as String,
        (message['input'] as Map?)?.cast<String, dynamic>(),
      ),
      'subagentFinished' => ClaudeSubagentFinished(
        id: message['id'] as String,
        result: message['result'] as String,
        isError: message['isError'] as bool,
      ),
      'turnCompleted' => ClaudeTurnCompleted(
        isError: message['isError'] as bool,
        costUsd: (message['costUsd'] as num).toDouble(),
        durationMs: message['durationMs'] as int,
        model: message['model'] as String,
        inputTokens: message['inputTokens'] as int,
        outputTokens: message['outputTokens'] as int,
        cacheReadTokens: message['cacheReadTokens'] as int,
        cacheCreationTokens: message['cacheCreationTokens'] as int,
      ),
      'contextUsage' => ClaudeContextUsage(
        usedTokens: message['usedTokens'] as int,
        contextWindowTokens: message['contextWindowTokens'] as int,
      ),
      _ => ClaudeFailure('Evento desconocido del CLI: ${message['type']}'),
    };
  }
}
