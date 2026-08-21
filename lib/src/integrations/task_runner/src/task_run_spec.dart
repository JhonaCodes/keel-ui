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

  /// Provider alias ('claude' | 'codex') — decides which CLI the isolate
  /// spawns and which JSONL dialect it parses.
  final String provider;

  /// Full `--mcp-config` JSON for the turn (e.g. the member's assigned
  /// executable tools), already encoded — a String is isolate-message-safe
  /// as-is.
  final String? mcpConfig;

  const TaskRunSpec({
    required this.prompt,
    required this.workingDirectory,
    required this.model,
    required this.fullFileSystemAccess,
    required this.effort,
    this.extraAllowedTools = const [],
    this.sessionId,
    this.additionalSystemPrompt,
    this.mcpConfig,
    this.provider = 'claude',
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
    'mcpConfig': mcpConfig,
    'provider': provider,
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
      mcpConfig: message['mcpConfig'] as String?,
      provider: message['provider'] as String? ?? 'claude',
    );
  }
}
