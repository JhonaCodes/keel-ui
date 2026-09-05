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

  /// Provider alias — decides whether the isolate starts a local CLI or an
  /// OpenAI-compatible API runner and which event dialect it normalizes.
  final String provider;

  /// API credential resolved by the main engine before crossing the isolate
  /// boundary. It is transient turn data: never persisted, logged, or sent
  /// to the model as prompt content.
  final String? providerApiKey;

  /// Full `--mcp-config` JSON for the turn (e.g. the member's assigned
  /// executable tools), already encoded — a String is isolate-message-safe
  /// as-is.
  final String? mcpConfig;

  /// El `settings.json` con los hooks de este turno, para claude — ya
  /// renderizado, con el marcador de directorio sin resolver. Se renderiza
  /// del lado del isolate principal porque acá no se alcanza ni el catálogo
  /// de hooks ni la bóveda de secrets.
  final String? hooksSettings;

  /// Lo mismo en TOML, para el perfil de codex.
  final String? hooksConfig;

  /// Los archivos que hay que dejar en el disco para que los hooks corran:
  /// el wrapper de cada uno y, si el cuerpo es una tool, su código.
  final Map<String, String> hookFiles;
  final List<LlmConversationMessage> conversationHistory;

  /// Este turno solo planifica: propone y no toca nada. Espejo de
  /// `LlmTurnSpec.planMode`; cada runner lo traduce a su CLI.
  final bool planMode;
  final int maxTurns;

  /// Techo en dólares para este turno. Cero: sin techo. Solo claude lo
  /// aplica (`--max-budget-usd`); los demás lo ignoran y el preflight lo dice.
  final double maxBudgetUsd;

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
    this.hooksSettings,
    this.hooksConfig,
    this.hookFiles = const {},
    this.conversationHistory = const [],
    this.planMode = false,
    this.maxTurns = 0,
    this.maxBudgetUsd = 0,
    this.provider = 'claude',
    this.providerApiKey,
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
    'hooksSettings': hooksSettings,
    'hooksConfig': hooksConfig,
    'hookFiles': hookFiles,
    'conversationHistory': conversationHistory
        .map((message) => message.toJson())
        .toList(),
    'planMode': planMode,
    'maxTurns': maxTurns,
    'maxBudgetUsd': maxBudgetUsd,
    'provider': provider,
    'providerApiKey': providerApiKey,
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
      hooksSettings: message['hooksSettings'] as String?,
      hooksConfig: message['hooksConfig'] as String?,
      hookFiles:
          (message['hookFiles'] as Map?)?.cast<String, String>() ?? const {},
      conversationHistory: (message['conversationHistory'] as List? ?? const [])
          .map(
            (entry) => LlmConversationMessage.fromJson(
              (entry as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
      // Tolerante a propósito: un mensaje armado antes de que el modo plan
      // existiera no trae la clave, y eso no es un turno roto.
      planMode: message['planMode'] as bool? ?? false,
      maxTurns: message['maxTurns'] as int? ?? 0,
      maxBudgetUsd: (message['maxBudgetUsd'] as num?)?.toDouble() ?? 0,
      provider: message['provider'] as String? ?? 'claude',
      providerApiKey: message['providerApiKey'] as String?,
    );
  }
}
