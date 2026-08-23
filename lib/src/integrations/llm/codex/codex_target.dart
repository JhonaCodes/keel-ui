/// Cómo se llega al modelo Codex: hoy solo el CLI. `CodexApi` (OpenAI
/// Responses API) se agrega cuando exista su runner — ver
/// arquitectura-llm-providers.
sealed class CodexTarget {
  const CodexTarget();
}

final class CodexCli extends CodexTarget {
  const CodexCli();
}
