part of '../task_runner.dart';

sealed class TaskEvent {
  const TaskEvent();

  static TaskEvent fromMessage(Map<String, dynamic> message) {
    return switch (message['type']) {
      'sessionStarted' => TaskSessionStarted(message['sessionId'] as String),
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
  const TaskTurnCompleted({
    required this.isError,
    required this.costUsd,
    required this.durationMs,
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
