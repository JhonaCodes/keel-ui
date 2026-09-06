import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/system_vault/system_vault.dart';

Directory _tempRepo() {
  final dir = Directory.systemTemp.createTempSync('keel-vault-git-');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return dir;
}

Future<ProcessResult> _git(Directory repo, List<String> arguments) {
  return Process.run('git', arguments, workingDirectory: repo.path);
}

Future<void> _initRepo(Directory repo) async {
  expect((await _git(repo, ['init'])).exitCode, 0);
  expect((await _git(repo, ['config', 'user.name', 'Keel Test'])).exitCode, 0);
  expect(
    (await _git(repo, ['config', 'user.email', 'keel@test.local'])).exitCode,
    0,
  );
}

Future<void> _configureRepoWithUnavailableSigning(Directory repo) async {
  await _initRepo(repo);
  expect((await _git(repo, ['config', 'commit.gpgSign', 'true'])).exitCode, 0);
  expect(
    (await _git(repo, [
      'config',
      'gpg.program',
      'keel-test-gpg-does-not-exist',
    ])).exitCode,
    0,
  );
}

Future<String> _read(Directory repo, List<String> arguments) async {
  final result = await _git(repo, arguments);
  expect(result.exitCode, 0, reason: '${result.stderr}');
  return (result.stdout as String).trim();
}

/// Escribe el zip y respalda, como hace el botón.
Future<String> _backup(Directory repo, String contents) {
  File('${repo.path}/keel-backup.zip').writeAsStringSync(contents);
  return commitVault(repo.path, message: 'respaldo $contents', push: false);
}

void main() {
  test('el commit del respaldo no depende de la firma GPG del usuario', () async {
    final repo = _tempRepo();
    await _configureRepoWithUnavailableSigning(repo);
    File('${repo.path}/keel-backup.zip').writeAsStringSync('respaldo');

    final result = await commitVault(
      repo.path,
      message: 'Respaldo de Keel',
      push: false,
    );

    expect(result, contains('Reemplacé el respaldo'));
    expect(await _read(repo, ['log', '-1', '--pretty=%s']), 'Respaldo de Keel');
    final signing = await _git(repo, ['config', '--get', 'commit.gpgSign']);
    expect((signing.stdout as String).trim(), 'true');
  });

  test('el segundo respaldo REEMPLAZA al primero: queda un solo commit', () async {
    final repo = _tempRepo();
    await _initRepo(repo);

    await _backup(repo, 'primero');
    await _backup(repo, 'segundo');

    // El pasivo que se elimina: dos respaldos no son dos commits.
    expect(await _read(repo, ['rev-list', '--count', 'HEAD']), '1');
    // Y el que queda es el último, no el primero.
    expect(await _read(repo, ['show', 'HEAD:keel-backup.zip']), 'segundo');
  });

  test('un vault con historia previa colapsa a un solo commit', () async {
    final repo = _tempRepo();
    await _initRepo(repo);
    // El vault real del usuario: un commit por respaldo, acumulados.
    for (final version in ['uno', 'dos', 'tres']) {
      File('${repo.path}/keel-backup.zip').writeAsStringSync(version);
      expect((await _git(repo, ['add', '-A'])).exitCode, 0);
      expect((await _git(repo, ['commit', '-m', version])).exitCode, 0);
    }
    expect(await _read(repo, ['rev-list', '--count', 'HEAD']), '3');

    await _backup(repo, 'cuarto');

    expect(await _read(repo, ['rev-list', '--count', 'HEAD']), '1');
    expect(await _read(repo, ['show', 'HEAD:keel-backup.zip']), 'cuarto');
  });

  test('un respaldo idéntico no reescribe nada, y lo dice', () async {
    final repo = _tempRepo();
    await _initRepo(repo);
    await _backup(repo, 'igual');
    final before = await _read(repo, ['rev-parse', 'HEAD']);

    final result = await _backup(repo, 'igual');

    expect(result, contains('idéntico'));
    expect(await _read(repo, ['rev-parse', 'HEAD']), before);
  });

  test('respaldar muchas veces NO infla el .git: la poda lo mantiene acotado', () async {
    // El defecto que costó 25 GB: cada respaldo es un zip entero y no se
    // diffea, así que amendar deja el blob anterior inalcanzable y el `.git`
    // crece un archivo por respaldo aunque el `git log` muestre uno solo.
    final repo = _tempRepo();
    await _initRepo(repo);

    const rounds = 10;
    for (var round = 0; round < rounds; round++) {
      File('${repo.path}/keel-backup.zip').writeAsBytesSync(_noise(round));
      await commitVault(repo.path, message: 'respaldo $round', push: false);
    }

    final backupKiB = File('${repo.path}/keel-backup.zip').lengthSync() ~/ 1024;
    final gitKiB = await _repoKiB(repo);

    expect(await _read(repo, ['rev-list', '--count', 'HEAD']), '1');
    // Sin poda esto daría ~10 respaldos de basura acumulada. El techo es la
    // poda relativa: dos respaldos, más el que acaba de entrar.
    expect(
      gitKiB,
      lessThan(backupKiB * 4),
      reason: 'el .git quedó en $gitKiB KiB para un respaldo de $backupKiB KiB',
    );
  });
}

/// Bytes incompresibles y distintos en cada ronda: un zip real tampoco se
/// comprime, y con texto repetido git empaquetaría todo a nada y el test no
/// probaría lo que dice probar.
Uint8List _noise(int seed) {
  final random = Random(seed);
  return Uint8List.fromList([
    for (var index = 0; index < 1024 * 1024; index++) random.nextInt(256),
  ]);
}

/// Lo que ocupa el repo según git, en KiB: objetos sueltos más empaquetados.
Future<int> _repoKiB(Directory repo) async {
  final output = await _read(repo, ['count-objects', '-v']);
  var total = 0;
  for (final line in output.split('\n')) {
    final parts = line.split(':');
    if (parts.length != 2) continue;
    if (parts.first.trim() case 'size' || 'size-pack') {
      total += int.tryParse(parts.last.trim()) ?? 0;
    }
  }
  return total;
}
