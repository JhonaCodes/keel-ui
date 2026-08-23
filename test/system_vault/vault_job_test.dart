import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/system_vault/system_vault.dart';

Directory _tempDir(String prefix) {
  final dir = Directory.systemTemp.createTempSync('keel-$prefix-');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return dir;
}

void main() {
  group('el respaldo se arma afuera del hilo de la UI', () {
    test('el encargo cruza a otro isolate y vuelve escrito', () async {
      final vault = _tempDir('vault');
      final saber = _tempDir('saber');
      File('${saber.path}/guia.md').writeAsStringSync('# Guía\nCómo se hace.');
      Directory('${saber.path}/sub').createSync();
      File('${saber.path}/sub/nota.md').writeAsStringSync('Una nota.');

      final job = VaultJob(
        destinationPath: '${vault.path}/$kVaultBackupFileName',
        catalog: const {
          'skills': [
            {'name': 'revisión', 'content': 'Mirá el diff.'},
          ],
        },
        settings: const {'chatFontScale': 0.9},
        secrets: const [
          {'name': 'LINEAR_API_KEY', 'description': 'La de Linear'},
        ],
        knowledgeRoots: {'manual': saber.path},
      );

      // Lo que importa de este test: que el encargo SEA enviable. Si no lo
      // fuera, esto explotaría en producción quince minutos después de
      // abrir la app, que es el peor momento para enterarse.
      final written = await Isolate.run(() => writeVaultArchive(job));

      expect(written.catalogCount, 1);
      expect(written.secretCount, 1);
      expect(written.documentCount, 2);
      expect(written.skipped, isEmpty);
      expect(written.byteLength, greaterThan(0));

      final file = File(job.destinationPath);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), written.byteLength);

      final contents = decodeVault(file.readAsBytesSync());
      expect(contents.catalog['skills']!.single['name'], 'revisión');
      expect(contents.settings['chatFontScale'], 0.9);
      expect(contents.secrets.single['name'], 'LINEAR_API_KEY');
      expect(contents.knowledgeDocs['manual']!.keys, {'guia.md', 'sub/nota.md'});
    });

    test('sigue siendo determinista: dos corridas, los mismos bytes', () async {
      final vault = _tempDir('vault');
      final job = VaultJob(
        destinationPath: '${vault.path}/$kVaultBackupFileName',
        catalog: const {
          'skills': [
            {'name': 'una', 'content': 'x'},
          ],
        },
      );

      final first = await Isolate.run(() => writeVaultArchive(job));
      final bytes = File(job.destinationPath).readAsBytesSync();
      final second = await Isolate.run(() => writeVaultArchive(job));

      expect(second.byteLength, first.byteLength);
      expect(File(job.destinationPath).readAsBytesSync(), bytes);
    });
  });

  group('lo que se saltea se nombra', () {
    test('un documento enorme queda afuera y lo dice', () {
      final vault = _tempDir('vault');
      final saber = _tempDir('saber');
      File('${saber.path}/chico.md').writeAsStringSync('ok');
      File(
        '${saber.path}/enorme.bin',
      ).writeAsBytesSync(List.filled(kMaxVaultDocBytes + 1, 0));

      final written = writeVaultArchive(
        VaultJob(
          destinationPath: '${vault.path}/$kVaultBackupFileName',
          knowledgeRoots: {'manual': saber.path},
        ),
      );

      expect(written.documentCount, 1);
      expect(written.skipped, ['manual/enorme.bin']);
    });

    test('los ocultos no entran', () {
      final vault = _tempDir('vault');
      final saber = _tempDir('saber');
      File('${saber.path}/visible.md').writeAsStringSync('ok');
      File('${saber.path}/.oculto').writeAsStringSync('no');
      Directory('${saber.path}/.git').createSync();
      File('${saber.path}/.git/config').writeAsStringSync('tampoco');

      final written = writeVaultArchive(
        VaultJob(
          destinationPath: '${vault.path}/$kVaultBackupFileName',
          knowledgeRoots: {'manual': saber.path},
        ),
      );

      expect(written.documentCount, 1);
      expect(written.skipped, isEmpty);
    });

    test('una carpeta que no existe no rompe el respaldo', () {
      final vault = _tempDir('vault');
      final written = writeVaultArchive(
        VaultJob(
          destinationPath: '${vault.path}/$kVaultBackupFileName',
          knowledgeRoots: const {'fantasma': '/no/existe/en/ningun/lado'},
        ),
      );

      expect(written.documentCount, 0);
      expect(File('${vault.path}/$kVaultBackupFileName').existsSync(), isTrue);
    });
  });
}
