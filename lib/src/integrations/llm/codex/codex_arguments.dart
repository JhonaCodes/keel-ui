import 'package:keel_ui/src/integrations/system_prompt/system_prompt.dart';
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
  return codexRoleWrappedPrompt(
    prompt: prompt,
    systemPrompt: additionalSystemPrompt,
  );
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
  final isResume = sessionId != null;

  return [
    'exec',
    if (isResume) ...['resume', sessionId],
    if (codexModel != null) ...['-m', codexModel],
    '--json',
    '--skip-git-repo-check',
    // `resume` has its own CLI parser. Unlike `exec`, it does not accept
    // sandbox, profile, or colour flags; forwarding them makes the resumed
    // turn fail before the model sees the prompt. The current Codex CLI has
    // no equivalent for preserving those process-level options on resume.
    if (!isResume) ...[
      '-s',
      fullFileSystemAccess ? 'danger-full-access' : 'workspace-write',
      if (codexProfileName != null) ...['-p', codexProfileName],
      '--color',
      'never',
    ],
    prompt,
  ];
}
