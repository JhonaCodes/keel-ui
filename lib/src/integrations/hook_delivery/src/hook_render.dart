part of '../hook_delivery.dart';

/// El comando que el CLI ejecuta para [hook], dado el directorio donde
/// quedaron los wrappers.
///
/// Siempre `bash <ruta>`, nunca la ruta pelada: así no hace falta que el
/// archivo tenga bit de ejecución, que es una fuente de fallos silenciosos
/// (el hook no corre y nadie se entera). Es también lo que hacía la config
/// manual que esto reemplaza.
String hookInvocation(Hook hook, String scriptDirectory) =>
    'bash ${_shellQuote('$scriptDirectory/${hook.scriptFileName}')}';

/// El `settings.json` que se le pasa a claude con `--settings`.
///
/// Solo lleva `hooks`: keel-ui administra los suyos y no adopta ni pisa lo
/// que el usuario tenga en `~/.claude/settings.json` — el CLI fusiona las
/// dos fuentes.
String renderClaudeSettings(List<Hook> hooks, {required String scriptDir}) {
  final byEvent = <String, List<Map<String, dynamic>>>{};
  for (final hook in hooks) {
    byEvent.putIfAbsent(hook.event.alias, () => []).add({
      if (hook.matcher.isNotEmpty) 'matcher': hook.matcher,
      'hooks': [
        {
          'type': 'command',
          'command': hookInvocation(hook, scriptDir),
          'timeout': hook.timeoutSeconds,
          'statusMessage': 'Hook: ${hook.name}',
        },
      ],
    });
  }
  return const JsonEncoder.withIndent('  ').convert({'hooks': byEvent});
}

/// Los hooks de codex como overrides `-c hooks.<Evento>=[...]`, uno por
/// línea, uno por evento.
///
/// Por evento y no por hook: dos `-c` sobre la misma clave se pisan, así
/// que todos los hooks de `PreToolUse` van en un solo valor. Antes esto era
/// un perfil TOML en `$CODEX_HOME` cargado con `-p`; codex 0.153 no acepta
/// `-p` en `exec resume`, y sin hooks al reanudar el gate de permisos no
/// cubría más que el primer turno de cada sesión.
String renderCodexOverrides(List<Hook> hooks, {required String scriptDir}) {
  final byEvent = <String, List<String>>{};
  for (final hook in hooks) {
    final matcher = hook.matcher.isNotEmpty
        ? 'matcher=${tomlString(hook.matcher)},'
        : '';
    final command = tomlString(hookInvocation(hook, scriptDir));
    byEvent.putIfAbsent(hook.event.alias, () => []).add(
      '{${matcher}hooks=[{type="command",command=$command,'
      'timeout=${hook.timeoutSeconds},'
      'statusMessage=${tomlString('Hook: ${hook.name}')}}]}',
    );
  }
  return [
    for (final entry in byEvent.entries)
      'hooks.${entry.key}=[${entry.value.join(',')}]',
  ].join('\n');
}

/// [value] entre comillas simples para shell, con las comillas simples de
/// adentro cerradas y reabiertas. Es el único quoting seguro para una ruta
/// arbitraria.
String _shellQuote(String value) => "'${value.replaceAll("'", r"'\''")}'";
