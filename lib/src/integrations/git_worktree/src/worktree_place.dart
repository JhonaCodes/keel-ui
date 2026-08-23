part of '../git_worktree.dart';

/// Un worktree del repo, tal como lo lista git.
class WorktreeEntry {
  const WorktreeEntry({
    required this.path,
    this.branch,
    this.head = '',
    this.bare = false,
    this.locked = false,
    this.prunable = false,
  });

  /// La raíz de esa copia de trabajo. Es la ruta que git considera canónica
  /// —con los symlinks ya resueltos—, no la que escribió el usuario.
  final String path;

  /// La rama que tiene tomada, sin `refs/heads/`. Null en HEAD suelto: ahí
  /// hay commits pero no hay nombre, y eso cambia lo que se puede hacer.
  final String? branch;

  final String head;
  final bool bare;

  /// `git worktree lock`. Un worktree bloqueado no se saca sin desbloquear,
  /// y quien lo bloqueó tenía un motivo.
  final bool locked;

  /// Git ya sabe que la carpeta no está: quedó el registro nada más.
  final bool prunable;

  /// El nombre de la carpeta. Es como se lo nombra en la UI: la ruta entera
  /// no entra en una línea y el final es la parte que distingue.
  String get name {
    final parts = path.split('/').where((part) => part.isNotEmpty);
    return parts.isEmpty ? path : parts.last;
  }

  bool get detached => branch == null && !bare;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorktreeEntry &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          branch == other.branch &&
          head == other.head &&
          bare == other.bare &&
          locked == other.locked &&
          prunable == other.prunable;

  @override
  int get hashCode => Object.hash(path, branch, head, bare, locked, prunable);

  @override
  String toString() => 'WorktreeEntry($path, branch: $branch)';
}

/// Dónde está parado un directorio dentro de su repo.
///
/// Se arma de una sola lectura y no toca nada. `trees` vacío significa "esto
/// no es un repo", que es un estado perfectamente normal: un proyecto puede
/// apuntar a una carpeta suelta.
class WorktreePlace {
  const WorktreePlace({
    required this.dir,
    this.top = '',
    this.trees = const [],
  });

  /// Lo que se preguntó: el directorio de trabajo del proyecto.
  final String dir;

  /// La raíz del worktree que contiene a [dir], según git. Vacío si [dir] no
  /// está adentro de ningún repo.
  final String top;

  /// Todos los worktrees del repo. El PRIMERO es siempre el principal —
  /// `git worktree list` lo garantiza, y de eso depende todo lo de acá.
  final List<WorktreeEntry> trees;

  bool get isRepo => top.isNotEmpty && trees.isNotEmpty;

  WorktreeEntry? get main => trees.isEmpty ? null : trees.first;

  /// El worktree en el que estás parado.
  WorktreeEntry? get here {
    for (final tree in trees) {
      if (tree.path == top) return tree;
    }
    return null;
  }

  /// Estás en uno de al lado, no en el principal. Es la pregunta que la app
  /// no sabía contestar.
  bool get isLinked {
    final current = here;
    final root = main;
    return current != null && root != null && current.path != root.path;
  }

  /// Cuántos worktrees tiene el repo, contando el principal. Un repo normal
  /// tiene uno.
  int get count => trees.length;

  /// La rama de acá, o vacío si es HEAD suelto o no hay repo.
  String get branch => here?.branch ?? '';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorktreePlace &&
          runtimeType == other.runtimeType &&
          dir == other.dir &&
          top == other.top &&
          listEquals(trees, other.trees);

  @override
  int get hashCode => Object.hash(dir, top, Object.hashAll(trees));

  @override
  String toString() =>
      'WorktreePlace($dir, linked: $isLinked, branch: $branch, '
      'trees: ${trees.length})';
}
