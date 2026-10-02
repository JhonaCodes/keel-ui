import 'dart:convert';

/// Los argumentos de un proceso `claude`. El prompt NO va acá: entra como
/// una línea stream-json por stdin (ver [claudeUserLine]), igual en el turno
/// suelto que en el proceso que sigue vivo entre turnos.
///
/// Por qué por stdin y no como argumento de `-p`: con el stdin abierto, un
/// mensaje que el usuario manda con el turno en curso entra en el próximo
/// corte del agente, entre una herramienta y la siguiente, sin matar el
/// proceso (verificado contra el CLI 2.1.280). Con el prompt en argv el
/// stdin se cerraba de entrada y la única forma de hacerle llegar algo era
/// cortarle el turno.
List<String> buildClaudeArguments({
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
}) => [
  '-p',
  '--input-format',
  'stream-json',
  ..._sharedClaudeArguments(
    model: model,
    effort: effort,
    allowedTools: allowedTools,
    systemPrompt: systemPrompt,
    mcpConfigPath: mcpConfigPath,
    claudeSettingsPath: claudeSettingsPath,
    fullFileSystemAccess: fullFileSystemAccess,
    sessionId: sessionId,
    planMode: planMode,
    maxTurns: maxTurns,
    maxBudgetUsd: maxBudgetUsd,
  ),
];

/// Un mensaje del usuario como línea stream-json para el stdin del CLI.
///
/// [priority] `next` lo entrega en el próximo corte del turno en curso, entre
/// una herramienta y la siguiente; si el turno termina antes, el CLI lo
/// atiende como turno siguiente en el mismo proceso, antes de salir.
String claudeUserLine(String text, {String? priority}) => jsonEncode({
  'type': 'user',
  'message': {'role': 'user', 'content': text},
  'priority': ?priority,
});

List<String> _sharedClaudeArguments({
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
  required double maxBudgetUsd,
}) {
  return [
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
