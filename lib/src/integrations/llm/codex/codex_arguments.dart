import 'package:keel_ui/src/integrations/system_prompt/system_prompt.dart';
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart'
    show codexModelArgument;

/// Codex no tiene flag de system prompt: el stack de instrucciones del
/// member viaja como preámbulo delimitado del prompt del usuario. En el
/// primer turno va completo; en un resume el ViewModel manda la versión
/// COMPACTA (identidad, reglas, contratos —sin skills ni saber), y acá se
/// antepone igual. Antes se descartaba en resume y la identidad vivía solo
/// en el turno 1: reglas y protocolo de cierre se perdían en silencio.
String buildCodexPrompt({
  required String prompt,
  required String? sessionId,
  required String? additionalSystemPrompt,
  required bool planMode,
}) {
  // El modo plan viaja adentro del prompt del usuario y no en el preámbulo,
  // justamente porque el preámbulo se descarta al reanudar. Es la única
  // forma de que un turno con `resume` —donde tampoco se puede cambiar el
  // sandbox— sepa que tiene que planificar y no ejecutar.
  final userPrompt = planMode ? '$kPlanModePrompt\n\n$prompt' : prompt;

  if (additionalSystemPrompt == null || additionalSystemPrompt.isEmpty) {
    return userPrompt;
  }
  return codexRoleWrappedPrompt(
    prompt: userPrompt,
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
  required bool planMode,
}) {
  // Misma regla que CodexCliService: solo un modelo de codex llega a `-m`.
  // Un member con alias de Claude (todo agente codex creado antes de que
  // los catálogos se separaran por proveedor) cae al modelo del config.
  final codexModel = codexModelArgument(model);
  final isResume = sessionId != null;
  // El modo plan le gana al acceso total: si el turno solo planifica, no
  // hay lectura que justifique dejarlo escribir.
  final sandbox = planMode
      ? 'read-only'
      : fullFileSystemAccess
      ? 'danger-full-access'
      : 'workspace-write';

  return [
    'exec',
    if (isResume) ...['resume', sessionId],
    if (codexModel != null) ...['-m', codexModel],
    '--json',
    '--skip-git-repo-check',
    // `resume` tiene su propio parser: no acepta `-s`, `-p` ni `--color`.
    // Pero sí acepta `-c clave=valor` (verificado en codex 0.149.1), que es
    // como el sandbox y el perfil de hooks sobreviven al reanudar. Antes se
    // descartaban: un turno de plan reanudado corría sin freno y los hooks
    // (incluido el gate de permisos) no aplicaban.
    if (!isResume) ...[
      '-s',
      sandbox,
      if (codexProfileName != null) ...['-p', codexProfileName],
      '--color',
      'never',
    ] else ...[
      '-c',
      'sandbox_mode="$sandbox"',
      if (codexProfileName != null) ...['-c', 'profile="$codexProfileName"'],
    ],
    prompt,
  ];
}
