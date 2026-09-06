import 'dart:io';

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
}
