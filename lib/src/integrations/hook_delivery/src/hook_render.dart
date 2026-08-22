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

/// El perfil TOML que se le capa a codex con `-p`.
///
/// Se escribe como perfil y no en `~/.codex/config.toml` para no tocar la
/// configuración del usuario: el perfil se capa encima, vale para esta
/// invocación, y se borra después.
String renderCodexConfig(List<Hook> hooks, {required String scriptDir}) {
  final buffer = StringBuffer()
    ..writeln('# Generado por keel-ui para un turno. No editar a mano.')
    ..writeln('# Se borra cuando el turno termina.');

  for (final hook in hooks) {
    buffer
      ..writeln()
      ..writeln('[[hooks.${hook.event.alias}]]');
    if (hook.matcher.isNotEmpty) {
      buffer.writeln('matcher = ${_tomlString(hook.matcher)}');
    }
    buffer
      ..writeln()
      ..writeln('[[hooks.${hook.event.alias}.hooks]]')
      ..writeln('type = "command"')
      ..writeln('command = ${_tomlString(hookInvocation(hook, scriptDir))}')
      ..writeln('timeout = ${hook.timeoutSeconds}')
      ..writeln('statusMessage = ${_tomlString('Hook: ${hook.name}')}');
  }
  return buffer.toString();
}

/// Una cadena TOML básica, con lo mínimo escapado. Los matchers traen `|` y
/// `.*`, que no necesitan nada; las rutas tampoco. Se escapa igual para que
/// un nombre raro no rompa el archivo entero.
String _tomlString(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n');
  return '"$escaped"';
}

/// [value] entre comillas simples para shell, con las comillas simples de
/// adentro cerradas y reabiertas. Es el único quoting seguro para una ruta
/// arbitraria.
String _shellQuote(String value) => "'${value.replaceAll("'", r"'\''")}'";
