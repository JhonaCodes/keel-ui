part of '../task_runner.dart';

/// Everything a single CLI turn needs. Every field is JSON-safe on purpose
/// — this crosses the isolate boundary as a plain [Map], never as a live
/// object.
class TaskRunSpec {
  final String prompt;
  final String workingDirectory;
  final String model;
  final bool fullFileSystemAccess;
  final String effort;
  final List<String> extraAllowedTools;
  final String? sessionId;
  final String? additionalSystemPrompt;

  const TaskRunSpec({
    required this.prompt,
    required this.workingDirectory,
    required this.model,
    required this.fullFileSystemAccess,
    required this.effort,
    this.extraAllowedTools = const [],
    this.sessionId,
    this.additionalSystemPrompt,
  });

  Map<String, dynamic> toMessage() => {
    'prompt': prompt,
    'workingDirectory': workingDirectory,
    'model': model,
    'fullFileSystemAccess': fullFileSystemAccess,
    'effort': effort,
    'extraAllowedTools': extraAllowedTools,
    'sessionId': sessionId,
    'additionalSystemPrompt': additionalSystemPrompt,
  };

  factory TaskRunSpec.fromMessage(Map<String, dynamic> message) {
    return TaskRunSpec(
      prompt: message['prompt'] as String,
      workingDirectory: message['workingDirectory'] as String,
      model: message['model'] as String,
      fullFileSystemAccess: message['fullFileSystemAccess'] as bool,
      effort: message['effort'] as String,
      extraAllowedTools:
          (message['extraAllowedTools'] as List?)?.cast<String>() ?? const [],
      sessionId: message['sessionId'] as String?,
      additionalSystemPrompt: message['additionalSystemPrompt'] as String?,
    );
  }
}
