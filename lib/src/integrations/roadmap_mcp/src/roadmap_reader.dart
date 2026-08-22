part of '../roadmap_mcp.dart';

/// La carpeta que un proyecto usa para su roadmap.
const kRoadmapFolder = 'TASKS';

/// En qué estado está una tarea. Vive en el `.md`, no en la base: es una
/// propiedad del código, y en una rama vieja la misma tarea no estaba hecha.
enum RoadmapState {
  libre('libre', 'Libre'),
  enCurso('en-curso', 'En curso'),
  hecho('hecho', 'Hecho'),
  bloqueado('bloqueado', 'Bloqueado');

  const RoadmapState(this.alias, this.label);

  final String alias;
  final String label;

  static RoadmapState fromAlias(String value) {
    for (final state in values) {
      if (state.alias == value.trim().toLowerCase()) return state;
    }
    return RoadmapState.libre;
  }
}

/// Contra qué resolvió la referencia de un bloqueante.
enum BlockerTarget {
  /// Apunta a una tarea que existe.
  found,

  /// No apunta a ninguna: la tarea se renombró, se renumeró o se borró y
  /// nadie arrastró la referencia.
  missing,

  /// El nombre suelto coincide con más de una tarea, así que no se puede
  /// saber a cuál se refiere.
  ambiguous,
}

/// Una tarea que otra tiene que resolver antes.
class RoadmapBlocker {
  /// Referencia a la tarea bloqueante, tal como la escribió quien la anotó.
  final String reference;

  /// Por qué bloquea. Sin esto, un bloqueante es una traba sin argumento y
  /// nadie sabe si sigue vigente.
  final String reason;

  /// Si ya está resuelto — el checkbox marcado.
  final bool resolved;

  /// Contra qué resolvió [reference] al mirar el roadmap entero.
  final BlockerTarget target;

  /// La ruta real de la tarea bloqueante, cuando [target] es
  /// [BlockerTarget.found].
  final String? targetPath;

  const RoadmapBlocker({
    required this.reference,
    required this.reason,
    required this.resolved,
    this.target = BlockerTarget.found,
    this.targetPath,
  });

  RoadmapBlocker resolvedAgainst(BlockerTarget target, String? path) =>
      RoadmapBlocker(
        reference: reference,
        reason: reason,
        resolved: resolved,
        target: target,
        targetPath: path,
      );

  /// Una referencia rota no se puede cumplir ni desmarcar: nadie puede
  /// terminar una tarea que no existe.
  bool get isBroken => target != BlockerTarget.found;

  Map<String, dynamic> toJson() => {
    'reference': reference,
    'reason': reason,
    'resolved': resolved,
    if (isBroken) 'referencia_rota': target.name,
    if (targetPath != null && targetPath != reference) 'apunta_a': targetPath,
  };
}

/// Una tarea del roadmap, leída del disco.
class RoadmapTask {
  /// Ruta relativa a la raíz del roadmap: `01-fundacion/02-shell.md`.
  final String path;
  final String folder;
  final String title;
  final RoadmapState state;
  final List<RoadmapBlocker> blockers;

  /// Un borrador todavía sin numerar: salida cruda de una investigación,
  /// esperando que el estandarizador la convierta.
  final bool isDraft;

  const RoadmapTask({
    required this.path,
    required this.folder,
    required this.title,
    required this.state,
    required this.blockers,
    required this.isDraft,
  });

  /// Si le falta que alguien resuelva algo antes.
  bool get hasOpenBlockers =>
      blockers.any((blocker) => !blocker.resolved && !blocker.isBroken);

  /// Bloqueantes cuya referencia no apunta a ninguna tarea real.
  ///
  /// Es el modo de falla que más caro sale: alguien renumera una carpeta, no
  /// arrastra las referencias, y la tarea queda trabada por algo que nadie
  /// puede terminar porque no existe. Se detecta acá en vez de confiar en que
  /// quien renumeró se acuerde.
  List<RoadmapBlocker> get brokenBlockers =>
      blockers.where((blocker) => blocker.isBroken).toList();

  /// Si se puede tomar: no está hecha, no es borrador, nadie la bloquea y
  /// ninguna de sus referencias está rota.
  ///
  /// Una referencia rota cierra la puerta a propósito. No se puede saber si
  /// la dependencia desapareció o solo cambió de nombre, y adivinar en
  /// cualquiera de las dos direcciones se equivoca en silencio. Lo que sí se
  /// puede es decir exactamente qué está roto.
  bool get isTakeable =>
      !isDraft &&
      state != RoadmapState.hecho &&
      !hasOpenBlockers &&
      brokenBlockers.isEmpty;
}

/// Lee la carpeta [kRoadmapFolder] de [projectPath].
///
/// **Sin caché, a propósito.** Un índice guardado en la base se desactualiza
/// solo: hacés `git pull`, cambiás de rama, otro agente agrega tareas, y la
/// base sigue mostrando la foto vieja. Recorrer la carpeta es barato y es la
/// única forma de estar en lo cierto.
List<RoadmapTask> readRoadmap(String projectPath) {
  final root = Directory('$projectPath/$kRoadmapFolder');
  if (!root.existsSync()) return const [];

  final prefix = '${root.path}/';
  final tasks = <RoadmapTask>[];

  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.md')) continue;
    final relative = entity.path.substring(prefix.length);

    // Los README describen el grupo, no son tareas. Y los ocultos tampoco.
    final name = relative.split('/').last;
    if (name.toUpperCase() == 'README.MD') continue;
    if (relative.startsWith('.') || relative.contains('/.')) continue;
    // Una tarea vive en una carpeta de grupo; un .md suelto en la raíz es
    // el índice o una nota, no una tarea.
    if (!relative.contains('/')) continue;

    try {
      tasks.add(parseRoadmapTask(relative, entity.readAsStringSync()));
    } catch (error) {
      Log.w('Roadmap: no pude leer $relative: $error');
    }
  }

  tasks.sort((a, b) => a.path.compareTo(b.path));
  // Segunda pasada: recién con TODAS las tareas a la vista se puede saber si
  // una referencia apunta a algo real.
  return _resolveBlockerTargets(tasks);
}

/// Resuelve la referencia de cada bloqueante contra las tareas que existen.
///
/// Acepta la ruta completa (`01-fundacion/02-shell.md`) y también el nombre
/// suelto (`02-shell.md`, o incluso `02-shell`), porque así es como lo
/// escribe cualquiera a mano. Un nombre suelto que coincide con dos tareas
/// queda marcado como ambiguo en vez de elegir una.
List<RoadmapTask> _resolveBlockerTargets(List<RoadmapTask> tasks) {
  final byPath = {for (final task in tasks) task.path};
  final byName = <String, List<String>>{};
  for (final task in tasks) {
    final name = task.path.split('/').last;
    byName.putIfAbsent(name, () => []).add(task.path);
    final sinExtension = name.endsWith('.md')
        ? name.substring(0, name.length - 3)
        : name;
    if (sinExtension != name) {
      byName.putIfAbsent(sinExtension, () => []).add(task.path);
    }
  }

  return [
    for (final task in tasks)
      RoadmapTask(
        path: task.path,
        folder: task.folder,
        title: task.title,
        state: task.state,
        isDraft: task.isDraft,
        blockers: [
          for (final blocker in task.blockers)
            _resolveBlocker(blocker, byPath, byName),
        ],
      ),
  ];
}

RoadmapBlocker _resolveBlocker(
  RoadmapBlocker blocker,
  Set<String> byPath,
  Map<String, List<String>> byName,
) {
  final reference = blocker.reference.trim();
  if (byPath.contains(reference)) {
    return blocker.resolvedAgainst(BlockerTarget.found, reference);
  }

  final candidatos = byName[reference.split('/').last] ?? const <String>[];
  return switch (candidatos.length) {
    1 => blocker.resolvedAgainst(BlockerTarget.found, candidatos.first),
    0 => blocker.resolvedAgainst(BlockerTarget.missing, null),
    _ => blocker.resolvedAgainst(BlockerTarget.ambiguous, null),
  };
}

final RegExp _frontMatter = RegExp(r'^---\s*\n(.*?)\n---\s*\n', dotAll: true);
final RegExp _blockerLine = RegExp(
  r'^\s*-\s*\[( |x|X)\]\s*(.+?)\s*(?:—|--)\s*(.+)$',
);

/// Convierte el texto de un `.md` de tarea en [RoadmapTask].
///
/// El formato es a propósito mínimo y legible a ojo: un frontmatter de pares
/// `clave: valor` —nada de YAML anidado— y una sección `## Bloqueantes` con
/// checkboxes. Se puede escribir a mano, se revisa en un PR, y se parsea sin
/// dependencias.
RoadmapTask parseRoadmapTask(String relativePath, String content) {
  final folder = relativePath.contains('/')
      ? relativePath.substring(0, relativePath.lastIndexOf('/'))
      : '';

  final fields = <String, String>{};
  final match = _frontMatter.firstMatch(content);
  if (match != null) {
    for (final line in match.group(1)!.split('\n')) {
      final cut = line.indexOf(':');
      if (cut <= 0) continue;
      fields[line.substring(0, cut).trim().toLowerCase()] = line
          .substring(cut + 1)
          .trim();
    }
  }

  final body = match == null ? content : content.substring(match.end);

  // El título sale del frontmatter, y si no está, del primer encabezado —
  // que es donde lo escribiría cualquiera sin leer la convención.
  var title = fields['titulo'] ?? fields['título'] ?? '';
  if (title.isEmpty) {
    final heading = RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(body);
    title = heading?.group(1)?.trim() ?? relativePath.split('/').last;
  }

  return RoadmapTask(
    path: relativePath,
    folder: folder,
    title: title,
    state: RoadmapState.fromAlias(fields['estado'] ?? ''),
    blockers: _parseBlockers(body),
    // Un borrador se declara, o se deduce de vivir en `_borradores/`.
    isDraft:
        (fields['estado'] ?? '').trim().toLowerCase() == 'borrador' ||
        folder.startsWith('_'),
  );
}

/// Los bloqueantes de la sección `## Bloqueantes`, hasta el próximo `##`.
List<RoadmapBlocker> _parseBlockers(String body) {
  final start = RegExp(
    r'^##\s+Bloqueantes\s*$',
    multiLine: true,
    caseSensitive: false,
  ).firstMatch(body);
  if (start == null) return const [];

  final rest = body.substring(start.end);
  final end = RegExp(r'^##\s+', multiLine: true).firstMatch(rest);
  final section = end == null ? rest : rest.substring(0, end.start);

  final blockers = <RoadmapBlocker>[];
  for (final line in section.split('\n')) {
    final match = _blockerLine.firstMatch(line);
    if (match == null) continue;
    blockers.add(
      RoadmapBlocker(
        reference: match.group(2)!.trim(),
        reason: match.group(3)!.trim(),
        resolved: match.group(1)!.toLowerCase() == 'x',
      ),
    );
  }
  return blockers;
}
