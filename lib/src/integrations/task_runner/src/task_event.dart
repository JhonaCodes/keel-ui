part of '../task_runner.dart';

sealed class TaskEvent {
  const TaskEvent();

  static TaskEvent fromMessage(Map<String, dynamic> message) {
    return switch (message['type']) {
      'sessionStarted' => TaskSessionStarted(message['sessionId'] as String),
      'processStarted' => TaskProcessStarted(message['pid'] as int),
      'assistantText' => TaskAssistantText(message['text'] as String),
      'toolUse' => TaskToolUse(
        message['name'] as String,
        (message['input'] as Map?)?.cast<String, dynamic>(),
      ),
      'reasoningChunk' => TaskReasoningChunk(message['text'] as String),
      'subagentStarted' => TaskSubagentStarted(
        id: message['id'] as String,
        agentType: message['agentType'] as String,
        ask: message['ask'] as String,
        prompt: message['prompt'] as String,
      ),
      'subagentText' => TaskSubagentText(
        message['id'] as String,
        message['text'] as String,
      ),
      'subagentReasoning' => TaskSubagentReasoning(
        message['id'] as String,
        message['text'] as String,
      ),
      'subagentToolUse' => TaskSubagentToolUse(
        message['id'] as String,
        message['name'] as String,
        (message['input'] as Map?)?.cast<String, dynamic>(),
      ),
      'subagentFinished' => TaskSubagentFinished(
        id: message['id'] as String,
        result: message['result'] as String,
        isError: message['isError'] as bool,
      ),
      'permissionDenied' => TaskPermissionDenied(
        toolName: message['toolName'] as String,
        message: message['message'] as String,
      ),
      'turnCompleted' => TaskTurnCompleted(
        isError: message['isError'] as bool,
        hasReportedFailure: message['hasReportedFailure'] as bool? ?? false,
        stopReason: message['stopReason'] as String? ?? '',
        costUsd: (message['costUsd'] as num).toDouble(),
        costReported: message['costReported'] as bool? ?? false,
        durationMs: message['durationMs'] as int,
        model: message['model'] as String? ?? '',
        inputTokens: message['inputTokens'] as int? ?? 0,
        outputTokens: message['outputTokens'] as int? ?? 0,
        cacheReadTokens: message['cacheReadTokens'] as int? ?? 0,
        cacheCreationTokens: message['cacheCreationTokens'] as int? ?? 0,
        tokensReported: message['tokensReported'] as bool? ?? false,
        usageIsCumulative: message['usageIsCumulative'] as bool? ?? false,
        contextUsedTokens: message['contextUsedTokens'] as int? ?? 0,
        contextWindowTokens: message['contextWindowTokens'] as int? ?? 0,
      ),
      'contextUsage' => TaskContextUsage(
        usedTokens: message['usedTokens'] as int,
        contextWindowTokens: message['contextWindowTokens'] as int,
      ),
      'notice' => TaskNotice(message['message'] as String),
      'failure' => TaskFailure(message['message'] as String),
      _ => TaskFailure(
        'Evento desconocido del task runner: ${message['type']}',
      ),
    };
  }
}

class TaskSessionStarted extends TaskEvent {
  final String sessionId;
  const TaskSessionStarted(this.sessionId);
}

/// El pid del proceso que largó el isolate. Solo sirve para mirarlo desde
/// afuera con `ps`: matarlo sigue siendo cosa del isolate, que es el único
/// que tiene el `Process`.
class TaskProcessStarted extends TaskEvent {
  final int pid;
  const TaskProcessStarted(this.pid);
}

class TaskAssistantText extends TaskEvent {
  final String text;
  const TaskAssistantText(this.text);
}

class TaskToolUse extends TaskEvent {
  final String name;
  final Map<String, dynamic>? input;
  const TaskToolUse(this.name, this.input);
}

class TaskReasoningChunk extends TaskEvent {
  final String text;
  const TaskReasoningChunk(this.text);
}

class TaskPermissionDenied extends TaskEvent {
  final String toolName;
  final String message;
  const TaskPermissionDenied({required this.toolName, required this.message});
}

class TaskTurnCompleted extends TaskEvent {
  final bool isError;
  final bool hasReportedFailure;

  /// Lo que el proveedor dijo sobre por qué paró. Vacío si no dijo nada.
  /// Hoy el único valor que se interpreta es `error_max_turns`.
  final String stopReason;
  final double costUsd;
  final bool costReported;
  final int durationMs;

  /// Los contadores del turno, para el ledger. Ver [ClaudeTurnCompleted]:
  /// es el mismo dato del otro lado del isolate.
  final String model;
  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheCreationTokens;
  final bool tokensReported;
  final bool usageIsCumulative;
  final int contextUsedTokens;
  final int contextWindowTokens;

  /// El turno se cortó por el tope de turnos agénticos de la capacidad, no
  /// porque algo fallara. Distinto para quien lo muestra: no hay nada que
  /// arreglar, hay un número que subir.
  bool get hitTurnCap => stopReason == 'error_max_turns';

  const TaskTurnCompleted({
    required this.isError,
    this.hasReportedFailure = false,
    this.stopReason = '',
    required this.costUsd,
    this.costReported = false,
    required this.durationMs,
    this.model = '',
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cacheReadTokens = 0,
    this.cacheCreationTokens = 0,
    this.tokensReported = false,
    this.usageIsCumulative = false,
    this.contextUsedTokens = 0,
    this.contextWindowTokens = 0,
  });

  /// A provider fallback is useful only when the runner could not provide a
  /// concrete cause. Otherwise it duplicates the error and falsely attributes
  /// Keel's own validation or safety stop to the remote provider.
  bool get needsProviderFailureFallback => isError && !hasReportedFailure;
}

class TaskContextUsage extends TaskEvent {
  final int usedTokens;
  final int contextWindowTokens;
  const TaskContextUsage({
    required this.usedTokens,
    required this.contextWindowTokens,
  });
}

class TaskFailure extends TaskEvent {
  final String message;
  const TaskFailure(this.message);
}

/// A visible compatibility or environment notice that does not fail a turn.
class TaskNotice extends TaskEvent {
  final String message;
  const TaskNotice(this.message);
}

/// Un `Task` que abrió un subagente. Ver [ClaudeSubagentStarted]: es el mismo
/// dato del otro lado del isolate.
class TaskSubagentStarted extends TaskEvent {
  final String id;
  final String agentType;
  final String ask;
  final String prompt;
  const TaskSubagentStarted({
    required this.id,
    required this.agentType,
    required this.ask,
    required this.prompt,
  });
}

class TaskSubagentText extends TaskEvent {
  final String id;
  final String text;
  const TaskSubagentText(this.id, this.text);
}

class TaskSubagentReasoning extends TaskEvent {
  final String id;
  final String text;
  const TaskSubagentReasoning(this.id, this.text);
}

class TaskSubagentToolUse extends TaskEvent {
  final String id;
  final String name;
  final Map<String, dynamic>? input;
  const TaskSubagentToolUse(this.id, this.name, this.input);
}

class TaskSubagentFinished extends TaskEvent {
  final String id;
  final String result;
  final bool isError;
  const TaskSubagentFinished({
    required this.id,
    required this.result,
    required this.isError,
  });
}
