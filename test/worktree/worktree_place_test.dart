import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/git_worktree/git_worktree.dart';

/// La salida real de `git worktree list --porcelain` con dos worktrees.
const _dos = '''
worktree /repos/keel-ui
HEAD baf6983d49f258fa3314b63e3c5f5ae1c0464d1a
branch refs/heads/main

worktree /repos/keel-ui-mapa
HEAD 780e2eb1f0aa2c3d4e5f60718293a4b5c6d7e8f9
branch refs/heads/feat/mapa
''';

void main() {
  group('leer la lista de worktrees', () {
    test('el primero es el principal y el resto cuelga de él', () {
      final trees = parseWorktreeList(_dos);

      expect(trees, hasLength(2));
      expect(trees.first.path, '/repos/keel-ui');
      expect(trees.first.branch, 'main');
      expect(trees.last.path, '/repos/keel-ui-mapa');
      // Sin el `refs/heads/`: es lo que se muestra y lo que se le pasa a
      // `git switch`.
      expect(trees.last.branch, 'feat/mapa');
      expect(trees.last.name, 'keel-ui-mapa');
    });

    test('HEAD suelto queda sin rama, no con una inventada', () {
      final trees = parseWorktreeList('''
worktree /repos/x
HEAD abc123
detached
''');
      expect(trees.single.branch, isNull);
      expect(trees.single.detached, isTrue);
    });

    test('bare, locked y prunable se leen sin valor', () {
      final trees = parseWorktreeList('''
worktree /repos/x.git
bare

worktree /repos/y
HEAD abc
branch refs/heads/y
locked el disco externo

worktree /repos/z
HEAD def
branch refs/heads/z
prunable gitdir file points to non-existent location
''');
      expect(trees, hasLength(3));
      expect(trees[0].bare, isTrue);
      expect(trees[0].branch, isNull);
      expect(trees[1].locked, isTrue);
      expect(trees[2].prunable, isTrue);
    });

    test('nada adentro es una lista vacía, no un registro fantasma', () {
      expect(parseWorktreeList(''), isEmpty);
      expect(parseWorktreeList('\n\n\n'), isEmpty);
    });
  });

  group('dónde estoy parado', () {
    final trees = parseWorktreeList(_dos);

    test('el de al lado se reconoce como aparte', () {
      final place = WorktreePlace(
        dir: '/repos/keel-ui-mapa',
        top: '/repos/keel-ui-mapa',
        trees: trees,
      );

      expect(place.isRepo, isTrue);
      expect(place.isLinked, isTrue);
      expect(place.branch, 'feat/mapa');
      expect(place.main?.path, '/repos/keel-ui');
      expect(place.count, 2);
    });

    test('el principal NO se marca, aunque tenga worktrees colgando', () {
      // Que existan otros no cambia nada de este lado: el aviso es sobre
      // dónde estás, no sobre cuántos hay.
      final place = WorktreePlace(
        dir: '/repos/keel-ui',
        top: '/repos/keel-ui',
        trees: trees,
      );
      expect(place.isLinked, isFalse);
    });

    test('una carpeta suelta no es repo y no marca nada', () {
      const place = WorktreePlace(dir: '/tmp/notas');
      expect(place.isRepo, isFalse);
      expect(place.isLinked, isFalse);
      expect(place.branch, '');
      expect(place.main, isNull);
    });

    test('preguntar desde una subcarpeta cae en su worktree', () {
      // `rev-parse --show-toplevel` ya devuelve la raíz; lo que se compara
      // es eso, no lo que escribió el usuario.
      final place = WorktreePlace(
        dir: '/repos/keel-ui-mapa/lib/src',
        top: '/repos/keel-ui-mapa',
        trees: trees,
      );
      expect(place.isLinked, isTrue);
      expect(place.here?.branch, 'feat/mapa');
    });
  });

  group('por qué hoy no se puede unificar', () {
    final here = parseWorktreeList(_dos).last;
    final root = parseWorktreeList(_dos).first;

    WorktreeUnifyPlan planWith({
      int running = 0,
      String branch = 'feat/mapa',
      bool locked = false,
      List<String> dirtyHere = const [],
      List<String> dirtyMain = const [],
      List<String> ignoredHere = const [],
    }) => WorktreeUnifyPlan(
      from: locked
          ? WorktreeEntry(path: here.path, branch: here.branch, locked: true)
          : here,
      mainTree: root,
      branch: branch,
      base: 'main',
      hasRemote: true,
      running: running,
      dirtyHere: dirtyHere,
      dirtyMain: dirtyMain,
      ignoredHere: ignoredHere,
    );

    test('todo limpio: se puede', () {
      expect(planWith().blockers, isEmpty);
      expect(planWith().canRun, isTrue);
    });

    test('una sesión corriendo lo traba: el CLI está escribiendo ahí', () {
      final plan = planWith(running: 1);
      expect(plan.canRun, isFalse);
      expect(plan.blockers.single, contains('una sesión corriendo'));
    });

    test('sin rama no hay nada que mudar', () {
      expect(planWith(branch: '').blockers, contains(contains('HEAD suelto')));
    });

    test('lo bloqueado no se saca por atrás', () {
      expect(
        planWith(locked: true).blockers,
        contains(contains('git worktree unlock')),
      );
    });

    test('cambios sin commitear de cualquiera de los dos lados', () {
      expect(
        planWith(dirtyHere: ['lib/a.dart']).blockers.single,
        contains('1 archivo sin commitear acá'),
      );
      expect(
        planWith(dirtyMain: ['a', 'b']).blockers.single,
        contains('2 archivos sin commitear'),
      );
    });

    test('un principal bare no tiene a dónde recibir la rama', () {
      // Setup común de quien vive en worktrees: un `repo.git` pelado y todas
      // las copias colgando. Sacar la única copia no te deja en ningún lado.
      final plan = WorktreeUnifyPlan(
        from: here,
        mainTree: const WorktreeEntry(path: '/repos/keel.git', bare: true),
        branch: 'feat/mapa',
        base: 'main',
        hasRemote: true,
      );
      expect(plan.canRun, isFalse);
      expect(plan.blockers.single, contains('bare'));
    });

    test('lo ignorado avisa pero no traba: es la carpeta que se borra', () {
      final plan = planWith(ignoredHere: ['.env', 'build/']);
      expect(plan.blockers, isEmpty);
      expect(plan.ignoredHere, hasLength(2));
    });
  });
}
