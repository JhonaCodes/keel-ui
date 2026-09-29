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

  /// Prior entries from exactly this Keel thread. API providers are
  /// stateless, whereas local CLIs resume with [sessionId]. The current user
  /// instruction remains [prompt] and is deliberately not repeated here.
  final List<LlmConversationMessage> conversationHistory;

  /// Este turno solo planifica: propone cómo haría el trabajo y no lo hace.
  ///
  /// Cada runner lo traduce a lo que su CLI entienda —Claude tiene un modo
  /// propio, los demás lo aproximan— porque no hay una forma común de decir
  /// «podés leer todo y no podés tocar nada».
  final bool planMode;

  /// Zero keeps the provider default. CLI runners apply a positive value when
  /// their provider exposes a real agentic-turn limit.
  final int maxTurns;

  /// Techo en dólares del turno. Cero: sin techo. Hoy solo claude lo aplica.
  final double maxBudgetUsd;

  /// Network inside a writable sandbox. Only codex sandboxes commands;
  /// the other runners ignore it.
  final bool sandboxNetworkAccess;

  /// The turn may not write (a consultation, a project the user does not
  /// maintain). Claude gets that by losing its write tools; codex has no
  /// tool allow-list, so it gets a read-only sandbox instead.
  final bool sandboxReadOnly;

  /// Keel's permission gate, for runners that receive permission requests
  /// themselves instead of through a hook (OpenCode's `permission.asked`).
  /// Null: no one to ask — the runner denies what would need asking.
  final String? permissionGateUrl;
  final String? permissionGateToken;

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
    this.conversationHistory = const [],
    this.planMode = false,
    this.maxTurns = 0,
    this.maxBudgetUsd = 0,
    this.sandboxNetworkAccess = false,
    this.sandboxReadOnly = false,
    this.permissionGateUrl,
    this.permissionGateToken,
  });
}
