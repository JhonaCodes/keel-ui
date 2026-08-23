/// Los argumentos de `claude -p` para un turno. Migrado literal de
/// `task_runner_isolate.dart` (rama `isCodex=false`).
List<String> buildClaudeArguments({
  required String prompt,
  required String model,
  required String effort,
  required List<String> allowedTools,
  required String systemPrompt,
  required String? mcpConfigPath,
  required String? claudeSettingsPath,
  required bool fullFileSystemAccess,
  required String? sessionId,
}) {
  return [
    '-p',
    prompt,
    '--output-format',
    'stream-json',
    '--verbose',
    // Sin esto el texto y el pensamiento de un subagente llegan mezclados
    // con los del padre: el mapa no puede darle nodo propio a algo que no
    // sabe distinguir.
    '--forward-subagent-text',
    '--model',
    model,
    '--effort',
    effort,
    '--allowedTools',
    allowedTools.join(','),
    '--append-system-prompt',
    systemPrompt,
    if (mcpConfigPath != null) ...['--mcp-config', mcpConfigPath, '--strict-mcp-config'],
    if (claudeSettingsPath != null) ...['--settings', claudeSettingsPath],
    if (fullFileSystemAccess) ...['--add-dir', '/'],
    if (sessionId != null) ...['--resume', sessionId],
  ];
}
