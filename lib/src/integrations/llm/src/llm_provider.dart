part of '../llm.dart';

/// Qué modelo corre un turno. Sealed a propósito: agregar un proveedor sin
/// extender `llm_dispatcher.dart` no compila — ver arquitectura-llm-providers
/// e invariantes-llm-providers.
sealed class LlmProvider {
  const LlmProvider();

  /// El único punto donde el alias persistido (`AgentProvider.alias`, hoy
  /// 'claude' | 'codex') se traduce al sealed. Dos copias de este mapeo
  /// divergiendo en silencio es justo lo que esta migración evita.
  factory LlmProvider.fromLegacyAlias(String alias) => switch (alias) {
    'codex' => const Codex(CodexCli()),
    'claude' => const Claude(ClaudeCli()),
    _ => throw ArgumentError.value(
      alias,
      'alias',
      'Proveedor LLM desconocido',
    ),
  };
}

final class Codex extends LlmProvider {
  final CodexTarget target;
  const Codex(this.target);
}

final class Claude extends LlmProvider {
  final ClaudeTarget target;
  const Claude(this.target);
}
