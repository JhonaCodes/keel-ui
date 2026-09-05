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
  required bool planMode,
  required int maxTurns,
  double maxBudgetUsd = 0,
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
    if (maxTurns > 0) ...['--max-turns', '$maxTurns'],
    // Lo que le queda a la sesión antes de su techo: el CLI corta solo, sin
    // esperar a que Keel lo vea en el `result` del turno siguiente.
    if (maxBudgetUsd > 0) ...['--max-budget-usd', '$maxBudgetUsd'],
    // El modo plan del propio CLI: trae su system prompt de planificación y
    // frena las escrituras aunque las tools estén permitidas. Por eso
    // `--allowedTools` NO se recorta acá — la superficie de tools tiene que
    // ser la misma que en el turno que después implementa, o el `--resume`
    // cambiaría de herramientas a mitad de conversación.
    if (planMode) ...['--permission-mode', 'plan'],
    '--allowedTools',
    allowedTools.join(','),
    '--append-system-prompt',
    systemPrompt,
    if (mcpConfigPath != null) ...[
      '--mcp-config',
      mcpConfigPath,
      '--strict-mcp-config',
    ],
    if (claudeSettingsPath != null) ...['--settings', claudeSettingsPath],
    if (fullFileSystemAccess) ...['--add-dir', '/'],
    if (sessionId != null) ...['--resume', sessionId],
  ];
}
