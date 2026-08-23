part of '../git_worktree.dart';

/// Lo que va a pasar al unificar, con todo lo que puede impedirlo.
///
/// Se arma ANTES de tocar nada y es lo que se muestra en el panel: quién se
/// va, qué se pierde con la carpeta, y por qué —si es que hay un porqué— hoy
/// no se puede. Los motivos son datos, no excepciones: una operación que
/// borra una carpeta no se entera a mitad de camino.
class WorktreeUnifyPlan {
  const WorktreeUnifyPlan({
    required this.from,
    required this.mainTree,
    required this.branch,
    required this.base,
    required this.hasRemote,
    this.dirtyHere = const [],
    this.dirtyMain = const [],
    this.ignoredHere = const [],
    this.running = 0,
    this.behind = 0,
  });

  /// El worktree que desaparece.
  final WorktreeEntry from;

  /// El principal, donde vas a seguir trabajando.
  final WorktreeEntry mainTree;

  /// La rama que se muda. Vacía en HEAD suelto, y ahí no hay nada que mudar.
  final String branch;

  /// `main` o `master`. Vacío si no se supo cuál es.
  final String base;

  final bool hasRemote;

  final List<String> dirtyHere;
  final List<String> dirtyMain;

  /// Lo ignorado que se va con la carpeta. No traba: avisa.
  final List<String> ignoredHere;

  /// Sesiones corriendo en este proyecto. Con una sola ya no se toca nada:
  /// el CLI está escribiendo adentro de la carpeta que estaríamos borrando.
  final int running;

  /// Cuántos commits de [base] le faltan a [branch] después del pull.
  final int behind;

  /// Por qué no se puede, en el orden en que conviene arreglarlo.
  List<String> get blockers => [
    if (running > 0)
      running == 1
          ? 'Hay una sesión corriendo en este proyecto. Esperala o pará el '
                'turno: el CLI está trabajando adentro de esta carpeta.'
          : 'Hay $running sesiones corriendo en este proyecto. Esperalas o '
                'pará los turnos: el CLI está trabajando adentro de esta '
                'carpeta.',
    if (branch.isEmpty)
      'Este worktree está en HEAD suelto, sin rama. No hay nada que mudar al '
          'principal: creá una rama acá primero.',
    if (mainTree.bare)
      'El repo principal es bare: no tiene copia de trabajo a la que mudarle '
          'la rama. Este worktree es todo lo que hay, y sacarlo no te deja '
          'en ningún lado.',
    if (from.locked)
      'El worktree está bloqueado con `git worktree lock`. Desbloquealo con '
          '`git worktree unlock` si de verdad querés sacarlo.',
    if (dirtyHere.isNotEmpty)
      'Tenés ${_files(dirtyHere.length)} sin commitear acá. '
          '${dirtyHere.length == 1 ? 'Se pierde' : 'Se pierden'} con la '
          'carpeta: commiteá o descartá antes.',
    if (dirtyMain.isNotEmpty)
      'El worktree principal tiene ${_files(dirtyMain.length)} sin commitear. '
          'Hay que cambiarle de rama y con eso encima no se puede.',
  ];

  bool get canRun => blockers.isEmpty;

  /// El resumen de una línea que va arriba del panel.
  String get headline => branch.isEmpty
      ? 'Este proyecto corre en un worktree aparte, sin rama.'
      : 'Este proyecto corre en un worktree aparte, sobre `$branch`.';
}

String _files(int count) => count == 1 ? '1 archivo' : '$count archivos';

/// Arma el plan leyendo el repo. No escribe nada.
///
/// [running] lo pone quien llama: la app sabe cuántas sesiones tiene vivas
/// este proyecto, y git no.
Future<WorktreeUnifyPlan?> planUnify(
  WorktreePlace place, {
  int running = 0,
}) async {
  final here = place.here;
  final root = place.main;
  if (!place.isLinked || here == null || root == null) return null;

  final branch = here.branch ?? '';
  final base = await _baseBranch(root.path);

  return WorktreeUnifyPlan(
    from: here,
    mainTree: root,
    branch: branch,
    base: base,
    hasRemote: await _hasOrigin(root.path),
    dirtyHere: await _dirtyPaths(here.path),
    dirtyMain: await _dirtyPaths(root.path),
    ignoredHere: await _ignoredPaths(here.path),
    running: running,
    behind: await _behind(root.path, branch, base),
  );
}
