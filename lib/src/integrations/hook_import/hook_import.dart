/// Trae a keel-ui los hooks que ya estaban escritos a mano en la
/// configuración de Claude Code.
///
/// Existe porque el punto de partida real no es cero: había una config
/// hecha a pulso en `~/.claude/settings.json` que se aplicaba a todos los
/// subprocesos que lanza esta app sin que la app lo supiera ni lo mostrara.
/// Traerlos es pasar eso de invisible a administrado.
///
/// Entran SIEMPRE apagados y verificando si su comando apunta a algo que
/// exista: una config vieja suele referirse a scripts que ya no están, y
/// prender eso sin mirar llenaría cada turno de errores.
library;

import 'dart:convert';
import 'dart:io';

import 'package:logger_rs/logger_rs.dart';

import 'package:keel_ui/src/modules/hooks/model/hook.dart';
import 'package:keel_ui/src/modules/hooks/model/hook_event.dart';

/// Un hook encontrado en una configuración de Claude Code.
class ImportableHook {
  final String name;
  final HookEvent event;
  final String matcher;
  final String command;
  final int timeoutSeconds;

  /// Null si el comando no nombra ningún archivo verificable (un `jq` inline,
  /// por ejemplo). True/false si lo nombra y existe o no.
  final bool? commandExists;

  const ImportableHook({
    required this.name,
    required this.event,
    required this.matcher,
    required this.command,
    required this.timeoutSeconds,
    required this.commandExists,
  });

  bool get isBroken => commandExists == false;
}

/// Todos los hooks que se puedan rescatar de la configuración de Claude
/// Code, sin repetir.
///
/// Los respaldos `.bak.*` se acumulan y traen las mismas entradas una y otra
/// vez, así que se deduplica por evento + matcher + comando: lo que importa
/// es la intención, no de cuál copia salió.
List<ImportableHook> readAllClaudeHooks() {
  final seen = <String>{};
  final all = <ImportableHook>[];
  final used = <String>{};

  for (final file in claudeSettingsCandidates()) {
    for (final hook in readClaudeHooks(file)) {
      final key = '${hook.event.alias}|${hook.matcher}|${hook.command}';
      if (!seen.add(key)) continue;
      all.add(
        ImportableHook(
          name: _uniqueName(_baseName(hook.name), used),
          event: hook.event,
          matcher: hook.matcher,
          command: hook.command,
          timeoutSeconds: hook.timeoutSeconds,
          commandExists: hook.commandExists,
        ),
      );
    }
  }
  return all;
}

/// Saca el sufijo numérico que agrega [_uniqueName] dentro de un archivo,
/// para que la unicidad se recalcule sobre el conjunto y no se acumule.
String _baseName(String name) =>
    name.replaceFirst(RegExp(r'-\d+\$'), '');

/// Los archivos donde suele estar la configuración manual, del más nuevo al
/// más viejo. Los `.bak` entran a propósito: es donde termina la config
/// cuando alguien la "limpió", y es justo la que hay que rescatar.
List<File> claudeSettingsCandidates() {
  final home = Platform.environment['HOME'] ?? '';
  if (home.isEmpty) return const [];

  final claudeDir = Directory('$home/.claude');
  final backups =
      (claudeDir.existsSync() ? claudeDir.listSync() : const <FileSystemEntity>[])
          .whereType<File>()
          .where((file) => file.path.contains('settings.json.bak'))
          .toList()
        ..sort(
          (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
        );

  return [
    File('$home/.claude/settings.json'),
    File('$home/.claude/settings.local.json'),
    ...backups,
  ];
}

/// Lee [file] y devuelve los hooks que declara.
List<ImportableHook> readClaudeHooks(File file) {
  if (!file.existsSync()) return const [];
  final Object? parsed;
  try {
    parsed = jsonDecode(file.readAsStringSync());
  } catch (error) {
    Log.w('No pude leer ${file.path}: $error');
    return const [];
  }
  if (parsed is! Map) return const [];

  final hooks = (parsed['hooks'] as Map?)?.cast<String, dynamic>();
  if (hooks == null) return const [];

  final found = <ImportableHook>[];
  final used = <String>{};

  for (final entry in hooks.entries) {
    final event = HookEvent.tryFromAlias(entry.key);
    if (event == null) continue;

    for (final group in (entry.value as List? ?? const [])) {
      if (group is! Map) continue;
      final matcher = group['matcher'] as String? ?? '';
      for (final handler in (group['hooks'] as List? ?? const [])) {
        if (handler is! Map) continue;
        // Solo `command`: los otros tipos que soporta claude (http,
        // mcp_tool, prompt, agent) no existen en codex, y este importador
        // trae lo que puede vivir en los dos.
        if ((handler['type'] as String? ?? 'command') != 'command') continue;
        final command = (handler['command'] as String? ?? '').trim();
        if (command.isEmpty) continue;

        found.add(
          ImportableHook(
            name: _uniqueName(_nameFor(command, event), used),
            event: event,
            matcher: matcher == '*' ? '' : matcher,
            command: command,
            timeoutSeconds:
                (handler['timeout'] as int? ?? kDefaultHookTimeoutSeconds)
                    .clamp(1, kMaxHookTimeoutSeconds),
            commandExists: _commandExists(command),
          ),
        );
      }
    }
  }
  return found;
}

/// Un nombre legible sacado del comando: el basename del script si lo hay.
///
/// Para un comando inline no se intenta adivinar: el primer token suele ser
/// `if` o `cmd=`, y un hook llamado "if" es peor que uno llamado por su
/// evento. Queda `<evento>-inline` y el usuario lo renombra sabiendo qué es.
String _nameFor(String command, HookEvent event) {
  final script = RegExp(
    r'([\w.-]+)\.(sh|py|dart|rb|js)\b',
  ).firstMatch(command);
  if (script != null) return _slug(script.group(1)!);

  final binary = RegExp(r'^([\w-]+)\s').firstMatch(command.trim());
  const shellNoise = {'if', 'bash', 'sh', 'cmd', 'test', 'for', 'while'};
  if (binary != null && !shellNoise.contains(binary.group(1))) {
    return _slug('${binary.group(1)}-${event.alias}');
  }
  return _slug('${event.alias}-inline');
}

String _slug(String value) {
  final slug = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return slug.isEmpty ? 'hook' : slug.substring(0, slug.length.clamp(0, 40));
}

String _uniqueName(String base, Set<String> used) {
  var name = base;
  var counter = 2;
  while (used.contains(name)) {
    name = '$base-$counter';
    counter++;
  }
  used.add(name);
  return name;
}

/// Si el comando nombra un archivo, si ese archivo existe. Null cuando el
/// comando no nombra ninguno (un `jq` inline se vale por sí mismo).
bool? _commandExists(String command) {
  final home = Platform.environment['HOME'] ?? '';
  final match = RegExp(r'(?:\$HOME|~|/)[\w./$-]+').firstMatch(command);
  if (match == null) return null;

  final path = match
      .group(0)!
      .replaceFirst(r'$HOME', home)
      .replaceFirst(RegExp(r'^~'), home);
  if (!path.startsWith('/')) return null;
  return File(path).existsSync() || Directory(path).existsSync();
}
