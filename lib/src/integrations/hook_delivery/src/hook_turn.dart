part of '../hook_delivery.dart';

/// Los hooks de un turno, ya listos para entregarle al CLI.
class TurnHooks {
  /// Contenido del `settings.json` de claude, o null si no hay nada que
  /// aplicar.
  final String? claudeSettings;

  /// Contenido del perfil TOML de codex, o null.
  final String? codexConfig;

  /// `{nombre de archivo: contenido}` de wrappers y código de tools.
  final Map<String, String> files;

  /// Qué quedó afuera y por qué, en castellano. Se muestra en el hilo: un
  /// guardarraíl que no se aplicó tiene que decirlo.
  final List<String> notes;

  const TurnHooks({
    this.claudeSettings,
    this.codexConfig,
    this.files = const {},
    this.notes = const [],
  });

  static const none = TurnHooks();

  bool get isEmpty => files.isEmpty;
}

/// Arma los hooks de un turno leyendo el catálogo vivo.
///
/// Corre SIEMPRE en el isolate principal, incluso para un proyecto: acá
/// están el catálogo, las tools y los valores de los secrets, y el isolate
/// del task runner no alcanza ninguno de los tres. Lo que cruza la frontera
/// es el resultado, que son puras Strings.
TurnHooks prepareTurnHooks({
  required List<Hook> catalog,
  required List<Tool> tools,
  required Map<String, String> secretValues,
  required HookProvider provider,
  AgentProfile? profile,
  Project? project,
}) {
  final resolved = resolveHooks(
    catalog: catalog,
    provider: provider,
    profile: profile,
    project: project,
  );
  if (resolved.hooks.isEmpty) {
    return TurnHooks(notes: resolved.notes);
  }

  final rendered = renderHookFiles(
    resolved.hooks,
    toolsByName: {for (final tool in tools) tool.name: tool},
    secretValues: secretValues,
  );

  // Un hook que no se pudo preparar no se declara: si se escribiera en la
  // config apuntando a un wrapper que no existe, el CLI fallaría en cada
  // evento y el usuario vería ruido en vez del problema real.
  final broken = rendered.issues.map((issue) => issue.hookName).toSet();
  final usable = resolved.hooks
      .where((hook) => !broken.contains(hook.name))
      .toList();

  final notes = [
    ...resolved.notes,
    for (final issue in rendered.issues) 'Hook "${issue.hookName}" sin aplicar: ${issue.message}.',
  ];

  if (usable.isEmpty) return TurnHooks(notes: notes);

  final isCodex = provider == HookProvider.codex;
  return TurnHooks(
    claudeSettings: isCodex
        ? null
        : renderClaudeSettings(usable, scriptDir: kHookDirPlaceholder),
    codexConfig: isCodex
        ? renderCodexConfig(usable, scriptDir: kHookDirPlaceholder)
        : null,
    files: rendered.files,
    notes: notes,
  );
}

/// Los nombres de secrets que hacen falta para estos hooks — los que
/// declaran las tools que usan como cuerpo.
List<String> hookSecretNames(List<Hook> hooks, List<Tool> tools) {
  final byName = {for (final tool in tools) tool.name: tool};
  return [
    for (final hook in hooks)
      if (hook.body case HookToolRef(:final toolName))
        ...?byName[toolName]?.secretNames,
  ];
}
