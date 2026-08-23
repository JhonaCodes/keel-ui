part of '../git_worktree.dart';

Future<({bool ok, String output})> _git(
  List<String> args, {
  required String cwd,
}) async {
  try {
    final result = await Process.run('git', args, workingDirectory: cwd);
    final output = [
      (result.stdout as String).trim(),
      (result.stderr as String).trim(),
    ].where((part) => part.isNotEmpty).join('\n');
    return (ok: result.exitCode == 0, output: output);
  } on ProcessException catch (error) {
    // Sin git instalado, o el directorio ya no existe. No es excepcional
    // para nosotros: es "no sé nada de este lugar".
    Log.d('git ${args.join(' ')} falló: ${error.message}');
    return (ok: false, output: error.message);
  }
}

/// Lee la salida de `git worktree list --porcelain`.
///
/// Aparte porque es la única parte de la lectura que se puede probar sin un
/// repo de verdad, y la que más fácil se rompe: el formato tiene líneas
/// opcionales y separa los registros con una línea en blanco.
List<WorktreeEntry> parseWorktreeList(String porcelain) {
  final trees = <WorktreeEntry>[];

  String? path;
  String head = '';
  String? branch;
  var bare = false;
  var locked = false;
  var prunable = false;

  void flush() {
    final root = path;
    if (root != null && root.isNotEmpty) {
      trees.add(
        WorktreeEntry(
          path: root,
          branch: branch,
          head: head,
          bare: bare,
          locked: locked,
          prunable: prunable,
        ),
      );
    }
    path = null;
    head = '';
    branch = null;
    bare = false;
    locked = false;
    prunable = false;
  }

  for (final raw in porcelain.split('\n')) {
    final line = raw.trimRight();
    if (line.isEmpty) {
      flush();
      continue;
    }
    final space = line.indexOf(' ');
    final key = space == -1 ? line : line.substring(0, space);
    final value = space == -1 ? '' : line.substring(space + 1).trim();

    switch (key) {
      case 'worktree':
        // Un registro nuevo sin línea en blanco de por medio no debería
        // pasar, pero si pasa el anterior se cierra igual en vez de
        // mezclarse con este.
        if (path != null) flush();
        path = value;
      case 'HEAD':
        head = value;
      case 'branch':
        branch = value.startsWith('refs/heads/')
            ? value.substring('refs/heads/'.length)
            : value;
      case 'bare':
        bare = true;
      case 'locked':
        locked = true;
      case 'prunable':
        prunable = true;
      case 'detached':
        branch = null;
    }
  }
  flush();

  return trees;
}

/// Dónde está parado [dir]. No escribe nada y nunca tira.
Future<WorktreePlace> readWorktreePlace(String dir) async {
  final path = dir.trim();
  if (path.isEmpty || !Directory(path).existsSync()) {
    return WorktreePlace(dir: dir);
  }

  final top = await _git(['rev-parse', '--show-toplevel'], cwd: path);
  if (!top.ok) return WorktreePlace(dir: dir);

  final list = await _git(['worktree', 'list', '--porcelain'], cwd: path);
  if (!list.ok) return WorktreePlace(dir: dir, top: top.output.trim());

  return WorktreePlace(
    dir: dir,
    top: top.output.trim(),
    trees: parseWorktreeList(list.output),
  );
}

/// Lo que hay sin commitear en [dir], una ruta por elemento.
Future<List<String>> _dirtyPaths(String dir) async {
  final status = await _git(['status', '--porcelain'], cwd: dir);
  if (!status.ok) return const [];
  return [
    for (final line in status.output.split('\n'))
      if (line.trim().isNotEmpty) line.length > 3 ? line.substring(3) : line,
  ];
}

/// Lo IGNORADO que vive en [dir] y solo ahí.
///
/// Se pregunta porque `git worktree remove` borra la carpeta entera, y lo
/// ignorado se va con ella sin aparecer en ningún `status`: el `.env` que
/// escribiste a mano, la build. Git no lo va a extrañar; vos sí.
Future<List<String>> _ignoredPaths(String dir) async {
  final status = await _git(['status', '--porcelain', '--ignored'], cwd: dir);
  if (!status.ok) return const [];
  return [
    for (final line in status.output.split('\n'))
      if (line.startsWith('!! ')) line.substring(3),
  ];
}

/// Si el repo de [dir] tiene un `origin` al que pedirle.
Future<bool> _hasOrigin(String dir) async =>
    (await _git(['remote', 'get-url', 'origin'], cwd: dir)).ok;

/// Cuál es la rama principal del repo: la que dice `origin/HEAD`, y si no
/// está, `main` o `master`, en ese orden.
///
/// Vacío significa que no se supo, y eso NO traba nada: se puede consolidar
/// igual, solo que sin traer nada de afuera antes.
Future<String> _baseBranch(String dir) async {
  final head = await _git([
    'symbolic-ref',
    '--short',
    'refs/remotes/origin/HEAD',
  ], cwd: dir);
  if (head.ok) {
    final value = head.output.trim();
    const prefix = 'origin/';
    if (value.startsWith(prefix)) return value.substring(prefix.length);
  }

  for (final name in const ['main', 'master']) {
    final exists = await _git([
      'show-ref',
      '--verify',
      '--quiet',
      'refs/heads/$name',
    ], cwd: dir);
    if (exists.ok) return name;
  }
  return '';
}

/// Cuántos commits de [base] le faltan a [branch]. -1 si no se pudo contar.
Future<int> _behind(String dir, String branch, String base) async {
  if (branch.isEmpty || base.isEmpty || branch == base) return 0;
  final count = await _git(['rev-list', '--count', '$branch..$base'], cwd: dir);
  if (!count.ok) return -1;
  return int.tryParse(count.output.trim()) ?? -1;
}
