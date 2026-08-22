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
      'permissionDenied' => TaskPermissionDenied(
        toolName: message['toolName'] as String,
        message: message['message'] as String,
      ),
      'turnCompleted' => TaskTurnCompleted(
        isError: message['isError'] as bool,
        costUsd: (message['costUsd'] as num).toDouble(),
        durationMs: message['durationMs'] as int,
        model: message['model'] as String? ?? '',
        inputTokens: message['inputTokens'] as int? ?? 0,
        outputTokens: message['outputTokens'] as int? ?? 0,
        cacheReadTokens: message['cacheReadTokens'] as int? ?? 0,
        cacheCreationTokens: message['cacheCreationTokens'] as int? ?? 0,
      ),
      'contextUsage' => TaskContextUsage(
        usedTokens: message['usedTokens'] as int,
        contextWindowTokens: message['contextWindowTokens'] as int,
      ),
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
  final double costUsd;
  final int durationMs;

  /// Los contadores del turno, para el ledger. Ver [ClaudeTurnCompleted]:
  /// es el mismo dato del otro lado del isolate.
  final String model;
  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheCreationTokens;

  const TaskTurnCompleted({
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
