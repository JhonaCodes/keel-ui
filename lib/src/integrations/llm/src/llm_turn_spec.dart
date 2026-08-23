part of '../llm.dart';

/// Todo lo que un [LlmRunner] necesita para correr un turno — el mismo
/// contenido que `TaskRunSpec`, sin el campo `provider` (ya resuelto en el
/// [LlmProvider] que decide qué runner se invoca) ni nada específico de
/// cómo `task_runner` cruza el isolate. `task_runner_isolate.dart` arma
/// esto a partir de su `TaskRunSpec` en el punto de llamada — este módulo
/// no importa `task_runner` para no crear una dependencia circular entre
/// las dos librerías (ver arquitectura-llm-providers).
class LlmTurnSpec {
  final String prompt;
  final String workingDirectory;
  final String model;
  final bool fullFileSystemAccess;
  final String effort;
  final List<String> extraAllowedTools;
  final String? sessionId;
  final String? additionalSystemPrompt;
  final String? mcpConfig;
  final String? hooksSettings;
  final String? hooksConfig;
  final Map<String, String> hookFiles;

  const LlmTurnSpec({
    required this.prompt,
    required this.workingDirectory,
    required this.model,
    required this.fullFileSystemAccess,
    required this.effort,
    this.extraAllowedTools = const [],
    this.sessionId,
    this.additionalSystemPrompt,
    this.mcpConfig,
    this.hooksSettings,
    this.hooksConfig,
    this.hookFiles = const {},
  });
}
