import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/git_worktree/git_worktree.dart';

/// Estas pruebas corren git DE VERDAD sobre repos de juguete, en una carpeta
/// temporal que se borra al terminar.
///
/// Es a propósito: lo que puede salir mal acá no es el parseo —eso ya se
/// prueba aparte— sino el ORDEN de los comandos, y eso solo se verifica
/// contra el git que hay instalado. Una carpeta que se borra a destiempo no
/// se descubre con un mock.
Future<String> _run(
  String executable,
  List<String> args, {
  required String cwd,
}) async {
  final result = await Process.run(executable, args, workingDirectory: cwd);
  if (result.exitCode != 0) {
    fail(
      '$executable ${args.join(' ')} falló en $cwd:\n'
      '${result.stdout}\n${result.stderr}',
    );
  }
  return (result.stdout as String).trim();
}

/// Un repo con su commit inicial, listo para colgarle worktrees.
Future<void> _initRepo(String dir) async {
  await _run('git', ['init', '-q', '-b', 'main', '.'], cwd: dir);
  await _run('git', ['config', 'user.email', 'test@keel.local'], cwd: dir);
  await _run('git', ['config', 'user.name', 'keel test'], cwd: dir);
  // Los repos de juguete no se firman: la firma abriría un pinentry y la
  // prueba quedaría colgada esperando una contraseña.
  await _run('git', ['config', 'commit.gpgsign', 'false'], cwd: dir);
}

Future<void> _commit(String dir, String file, String text) async {
  File('$dir/$file').writeAsStringSync(text);
  await _run('git', ['add', '-A'], cwd: dir);
  await _run('git', ['commit', '-qm', 'agrego $file'], cwd: dir);
}

void main() {
  late Directory tmp;
  late String root;
  late String main_;
  late String aparte;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('keel-worktree');
    // macOS mete un symlink en /var: git informa la ruta resuelta y la
    // comparación se hace contra eso.
    root = tmp.resolveSymbolicLinksSync();
    main_ = '$root/principal';
    aparte = '$root/aparte';
    Directory(main_).createSync();
    await _initRepo(main_);
    await _commit(main_, 'a.txt', 'uno\n');
    await _run('git', [
      'worktree',
      'add',
      '-q',
      aparte,
      '-b',
      'feat/paralelo',
    ], cwd: main_);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('el principal no se marca; el de al lado sí', () async {
    final desdeElPrincipal = await readWorktreePlace(main_);
    expect(desdeElPrincipal.isRepo, isTrue);
    expect(desdeElPrincipal.isLinked, isFalse);
    expect(desdeElPrincipal.branch, 'main');

    final desdeAlLado = await readWorktreePlace(aparte);
    expect(desdeAlLado.isLinked, isTrue);
    expect(desdeAlLado.branch, 'feat/paralelo');
    expect(desdeAlLado.main?.path, main_);
  });

  test('una carpeta que no es repo no dice nada', () async {
    final suelta = Directory('$root/suelta')..createSync();
    final place = await readWorktreePlace(suelta.path);
    expect(place.isRepo, isFalse);
    expect(place.isLinked, isFalse);
  });

  test('unificar trae la rama y se lleva la carpeta', () async {
    await _commit(aparte, 'b.txt', 'dos\n');
    final commit = await _run('git', ['rev-parse', 'HEAD'], cwd: aparte);

    final plan = await planUnify(await readWorktreePlace(aparte));
    expect(plan, isNotNull);
    expect(plan!.canRun, isTrue, reason: plan.blockers.join(' / '));

    final report = await unifyWorktree(plan);

    expect(report.ok, isTrue, reason: report.steps.map((s) => s.detail).join());
    expect(report.moved, isTrue);
    expect(report.path, main_);
    // La carpeta de al lado ya no está…
    expect(Directory(aparte).existsSync(), isFalse);
    // …y la rama, con su commit, está en el principal.
    expect(
      await _run('git', ['rev-parse', '--abbrev-ref', 'HEAD'], cwd: main_),
      'feat/paralelo',
    );
    expect(await _run('git', ['rev-parse', 'HEAD'], cwd: main_), commit);
    expect(File('$main_/b.txt').existsSync(), isTrue);

    // Y el registro quedó limpio: un solo worktree.
    final despues = await readWorktreePlace(main_);
    expect(despues.count, 1);
    expect(despues.isLinked, isFalse);
  });

  test('sin origin no hay pull, y eso se dice en vez de fallar', () async {
    final plan = await planUnify(await readWorktreePlace(aparte));
    final report = await unifyWorktree(plan!);

    final pull = report.steps.first;
    expect(pull.result, WorktreeStepResult.skipped);
    expect(pull.detail, contains('origin'));
    expect(report.ok, isTrue);
  });

  test(
    'con cambios sin commitear no se puede: se pierden con la carpeta',
    () async {
      File('$aparte/sucio.txt').writeAsStringSync('a medio hacer\n');

      final plan = await planUnify(await readWorktreePlace(aparte));
      expect(plan!.canRun, isFalse);
      expect(plan.blockers.single, contains('sin commitear acá'));
      // Y sigue todo en su lugar: preguntar no toca nada.
      expect(Directory(aparte).existsSync(), isTrue);
    },
  );

  test('una sesión corriendo lo traba aunque el repo esté limpio', () async {
    final plan = await planUnify(await readWorktreePlace(aparte), running: 2);
    expect(plan!.canRun, isFalse);
    expect(plan.blockers.first, contains('2 sesiones corriendo'));
  });

  test('lo ignorado se enumera antes de borrarlo', () async {
    File('$main_/.gitignore').writeAsStringSync('.env\n');
    await _run('git', ['add', '-A'], cwd: main_);
    await _run('git', ['commit', '-qm', 'ignore'], cwd: main_);
    await _run('git', ['merge', '-q', 'main'], cwd: aparte);
    File('$aparte/.env').writeAsStringSync('TOKEN=abc\n');

    final plan = await planUnify(await readWorktreePlace(aparte));
    // No traba —es la carpeta que se va— pero queda dicho.
    expect(plan!.canRun, isTrue, reason: plan.blockers.join(' / '));
    expect(plan.ignoredHere, contains('.env'));
  });

  group('con un remoto de verdad', () {
    late String origin;

    setUp(() async {
      origin = '$root/origin.git';
      await _run('git', [
        'init',
        '-q',
        '--bare',
        '-b',
        'main',
        origin,
      ], cwd: root);
      await _run('git', ['remote', 'add', 'origin', origin], cwd: main_);
      await _run('git', ['push', '-q', '-u', 'origin', 'main'], cwd: main_);

      // Alguien más empuja a main mientras vos trabajás al lado.
      final otro = '$root/otro';
      await _run('git', ['clone', '-q', origin, otro], cwd: root);
      await _run('git', ['config', 'user.email', 'o@keel.local'], cwd: otro);
      await _run('git', ['config', 'user.name', 'otro'], cwd: otro);
      await _run('git', ['config', 'commit.gpgsign', 'false'], cwd: otro);
      await _commit(otro, 'c.txt', 'tres\n');
      await _run('git', ['push', '-q', 'origin', 'main'], cwd: otro);
    });

    test('trae main al principal antes de mudar la rama', () async {
      await _commit(aparte, 'b.txt', 'dos\n');

      final plan = await planUnify(await readWorktreePlace(aparte));
      expect(plan!.hasRemote, isTrue);
      expect(plan.base, 'main');

      final report = await unifyWorktree(plan);
      expect(report.ok, isTrue);
      expect(report.steps.first.result, WorktreeStepResult.ok);

      // El main local del principal se movió con lo del remoto…
      expect(
        await _run('git', ['rev-parse', 'main'], cwd: main_),
        await _run('git', ['rev-parse', 'origin/main'], cwd: main_),
      );
      // …y la rama quedó a un commit de distancia, dicho en el informe.
      expect(report.behind, 1);
      expect(
        await _run('git', ['rev-parse', '--abbrev-ref', 'HEAD'], cwd: main_),
        'feat/paralelo',
      );
    });
  });
}
