import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart'
    show codexModelArgument;

/// Codex no tiene flag de system prompt: en el PRIMER turno de una sesión el
/// stack de instrucciones del member viaja como preámbulo delimitado del
/// prompt del usuario (los turnos con resume ya lo tienen en el historial
/// del thread). Migrado literal de `CodexCliService`/`task_runner_isolate`.
String buildCodexPrompt({
  required String prompt,
  required String? sessionId,
  required String? additionalSystemPrompt,
}) {
  if (sessionId != null ||
      additionalSystemPrompt == null ||
      additionalSystemPrompt.isEmpty) {
    return prompt;
  }
  return '### Instrucciones de tu rol (fijas para toda la conversación)\n'
      '$additionalSystemPrompt\n'
      '### Fin de instrucciones\n\n'
      '$prompt';
}

/// Los argumentos de `codex exec` para un turno. Migrado literal de
/// `task_runner_isolate.dart` (rama `isCodex=true`).
List<String> buildCodexArguments({
  required String prompt,
  required String? sessionId,
  required String model,
  required bool fullFileSystemAccess,
  required String? codexProfileName,
}) {
  // Misma regla que CodexCliService: solo un modelo de codex llega a `-m`.
  // Un member con alias de Claude (todo agente codex creado antes de que
  // los catálogos se separaran por proveedor) cae al modelo del config.
  final codexModel = codexModelArgument(model);

  return [
    'exec',
    if (sessionId != null) ...['resume', sessionId],
    if (codexModel != null) ...['-m', codexModel],
    '--json',
    '--skip-git-repo-check',
    '-s',
    fullFileSystemAccess ? 'danger-full-access' : 'workspace-write',
    if (codexProfileName != null) ...['-p', codexProfileName],
    '--color',
    'never',
    prompt,
  ];
}
