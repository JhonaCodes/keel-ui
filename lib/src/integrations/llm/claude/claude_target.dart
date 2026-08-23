/// Cómo se llega al modelo Claude: hoy solo el CLI. `ClaudeApi` (Anthropic
/// Messages API) se agrega cuando exista su runner — ver
/// arquitectura-llm-providers.
sealed class ClaudeTarget {
  const ClaudeTarget();
}

final class ClaudeCli extends ClaudeTarget {
  const ClaudeCli();
}
