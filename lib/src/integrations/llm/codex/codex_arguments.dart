import 'package:keel_ui/src/integrations/system_prompt/system_prompt.dart';
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart'
    show codexModelArgument;
import 'package:keel_ui/src/shared/utils/toml_string.dart';

/// El prompt del usuario para un turno de codex.
///
/// Solo el pedido, más el modo plan cuando corresponde. Las instrucciones de
/// rol ya no viajan acá: van por `developer_instructions` (ver
/// [buildCodexArguments]), que codex trata como mensaje de desarrollador y
/// guarda en el hilo, así que un resume las tiene sin repetirlas. Antes se
/// mandaban envueltas en el prompt en cada turno: doble costo y un modelo
/// que a veces contestaba sobre sus instrucciones en vez de obedecerlas.
String buildCodexPrompt({required String prompt, required bool planMode}) {
  // El modo plan viaja adentro del prompt: es del turno, no de la sesión.
  return planMode ? '$kPlanModePrompt\n\n$prompt' : prompt;
}

/// Los argumentos de `codex exec` para un turno.
///
/// Todo lo configurable va por `-c clave=valor`, que es lo único que `exec`
/// y `exec resume` aceptan por igual en codex 0.153 (`-p` no existe en
/// resume y `-c profile=` está rechazado como legacy). El sandbox del turno
/// nuevo va por `-s` porque el CLI lo exige así en el primer turno.
List<String> buildCodexArguments({
  required String prompt,
  required String? sessionId,
  required String model,
  required bool fullFileSystemAccess,
  required bool planMode,

  /// El system prompt del member. Solo se manda en el PRIMER turno: codex
  /// lo persiste en el hilo como mensaje de desarrollador y lo reenvía en
  /// cada resume (verificado capturando los requests, 2026-09-05).
  String? developerInstructions,

  /// Overrides `clave=valor` ya armados (hooks, MCP). Cada uno es un `-c`.
  List<String> configOverrides = const [],

  /// Si el turno lleva hooks. Codex 0.153 no corre un hook que no esté
  /// «trusted» de forma persistente —y los de Keel se generan por turno—,
  /// así que sin `--dangerously-bypass-hook-trust` los ignora EN SILENCIO:
  /// el gate de permisos y el tope de herramientas no aplicarían y nadie
  /// se enteraría. Los hooks son de Keel o del catálogo del usuario, ya
  /// revisados: el flag dice lo que es.
  bool bypassHookTrust = false,
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
    // `resume` tiene su propio parser: no acepta `-s` ni `--color`, pero sí
    // `-c sandbox_mode=...`, que es como un turno de plan reanudado sigue
    // teniendo freno.
    if (!isResume) ...['-s', sandbox, '--color', 'never'] else ...[
      '-c',
      'sandbox_mode=${tomlString(sandbox)}',
    ],
    if (!isResume &&
        developerInstructions != null &&
        developerInstructions.isNotEmpty) ...[
      '-c',
      'developer_instructions=${tomlString(developerInstructions)}',
    ],
    for (final override in configOverrides) ...['-c', override],
    if (bypassHookTrust) '--dangerously-bypass-hook-trust',
    prompt,
  ];
}
