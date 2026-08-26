import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/roadmap_mcp/roadmap_mcp.dart';

void main() {
  late Directory project;

  setUp(() => project = Directory.systemTemp.createTempSync('keel_ignore'));
  tearDown(() => project.deleteSync(recursive: true));

  File gitignore() => File('${project.path}/.gitignore');
  void hacerRepo() => Directory('${project.path}/.git').createSync();

  test('sin repo git no escribe nada', () async {
    expect(await ensureRoadmapIgnored(project.path), isFalse);
    expect(gitignore().existsSync(), isFalse);
  });

  test('en un worktree, donde `.git` es un archivo, igual escribe', () async {
    File('${project.path}/.git').writeAsStringSync('gitdir: /otro/lado\n');

    expect(await ensureRoadmapIgnored(project.path), isTrue);
    expect(gitignore().readAsStringSync(), contains('TASKS/'));
  });

  test('crea el .gitignore con el bloque explicado', () async {
    hacerRepo();

    expect(await ensureRoadmapIgnored(project.path), isTrue);

    final contenido = gitignore().readAsStringSync();
    expect(contenido, contains('# Keel administra el roadmap'));
    expect(contenido, contains('TASKS/'));
  });

  test('no lo escribe dos veces', () async {
    hacerRepo();
    await ensureRoadmapIgnored(project.path);
    final primera = gitignore().readAsStringSync();

    expect(await ensureRoadmapIgnored(project.path), isFalse);
    expect(gitignore().readAsStringSync(), primera);
  });

  test('respeta lo que ya estaba y no lo deja pegado', () async {
    hacerRepo();
    gitignore().writeAsStringSync('build/\n.env');

    await ensureRoadmapIgnored(project.path);

    final lineas = gitignore().readAsStringSync().split('\n');
    expect(lineas.first, 'build/');
    expect(lineas, contains('.env'));
    expect(lineas, contains('TASKS/'));
    expect(
      lineas.any((linea) => linea.startsWith('.env#')),
      isFalse,
      reason: 'un archivo sin salto final no puede pegarse con el bloque',
    );
  });

  group('reconoce que ya está ignorada escrita de otra forma', () {
    for (final patron in ['TASKS', 'TASKS/', '/TASKS/', 'TASKS/**']) {
      test('«$patron»', () async {
        hacerRepo();
        gitignore().writeAsStringSync('$patron\n');

        expect(await ensureRoadmapIgnored(project.path), isFalse);
        expect(gitignore().readAsStringSync(), '$patron\n');
      });
    }
  });

  test('un comentario que la nombra no cuenta como regla', () async {
    hacerRepo();
    gitignore().writeAsStringSync('# TASKS/ se comitea a propósito\n');

    expect(await ensureRoadmapIgnored(project.path), isTrue);
  });
}
