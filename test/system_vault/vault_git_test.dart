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

Future<void> _configureRepoWithUnavailableSigning(Directory repo) async {
  expect((await _git(repo, ['init'])).exitCode, 0);
  expect((await _git(repo, ['config', 'user.name', 'Keel Test'])).exitCode, 0);
  expect(
    (await _git(repo, ['config', 'user.email', 'keel@test.local'])).exitCode,
    0,
  );
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

void main() {
  test('el commit automático no depende de la firma GPG del usuario', () async {
    final repo = _tempRepo();
    await _configureRepoWithUnavailableSigning(repo);
    File('${repo.path}/keel-backup.zip').writeAsStringSync('respaldo');

    final result = await commitVault(
      repo.path,
      message: 'Respaldo de Keel',
      push: false,
    );

    expect(result, 'Commiteé el respaldo en el vault.');
    final subject = await _git(repo, ['log', '-1', '--pretty=%s']);
    expect(subject.exitCode, 0);
    expect((subject.stdout as String).trim(), 'Respaldo de Keel');
    final signing = await _git(repo, ['config', '--get', 'commit.gpgSign']);
    expect((signing.stdout as String).trim(), 'true');
  });
}
