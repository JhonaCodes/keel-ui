import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:keel_ui/src/integrations/keel_e2e/keel_e2e.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('keel-e2e-binary-');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  bool existsOnDisk(String path) => File(path).existsSync();

  test('KEEL_E2E_BIN gana sobre cualquier otra búsqueda, si existe', () {
    final override = p.join(tmp.path, 'custom', 'keel_e2e');
    File(override).createSync(recursive: true);

    final resolved = resolveKeelE2eBinary(
      envOverride: override,
      resolvedExecutablePath: p.join(tmp.path, 'Keel.app', 'Contents', 'MacOS', 'keel_ui'),
      exists: existsOnDisk,
    );

    expect(resolved, override);
  });

  test('KEEL_E2E_BIN puesto pero inexistente no cae a otra ruta', () {
    final resolved = resolveKeelE2eBinary(
      envOverride: p.join(tmp.path, 'no-existe', 'keel_e2e'),
      resolvedExecutablePath: p.join(tmp.path, 'Keel.app', 'Contents', 'MacOS', 'keel_ui'),
      exists: existsOnDisk,
    );

    expect(resolved, isNull);
  });

  test('sin override, busca el bundle de la app por el .app ancestro', () {
    final exe = p.join(tmp.path, 'Applications', 'Keel.app', 'Contents', 'MacOS', 'keel_ui');
    final bundled = p.join(
      tmp.path,
      'Applications',
      'Keel.app',
      'Contents',
      'Resources',
      'keel_e2e',
      'bin',
      'keel_e2e',
    );
    File(bundled).createSync(recursive: true);

    // RED antes del fix: `resolveKeelE2eBinary` no existía, así que esta
    // llamada ni compilaba.
    final resolved = resolveKeelE2eBinary(
      resolvedExecutablePath: exe,
      exists: existsOnDisk,
    );

    expect(resolved, bundled);
  });

  test(
    'sin bundle, busca el build hermano subiendo hasta una carpeta '
    '"keel-ui"',
    () {
      final exe = p.join(
        tmp.path,
        'KEEL',
        'keel-ui',
        'build',
        'macos',
        'Build',
        'Products',
        'Debug',
        'keel_ui.app',
        'Contents',
        'MacOS',
        'keel_ui',
      );
      final devBuild = p.join(
        tmp.path,
        'KEEL',
        'keel-e2e',
        'build',
        'bundle',
        'bin',
        'keel_e2e',
      );
      File(devBuild).createSync(recursive: true);

      final resolved = resolveKeelE2eBinary(
        resolvedExecutablePath: exe,
        exists: existsOnDisk,
      );

      expect(resolved, devBuild);
    },
  );

  test('sin ninguno de los tres, devuelve null', () {
    final resolved = resolveKeelE2eBinary(
      resolvedExecutablePath: p.join(tmp.path, 'solo', 'un', 'binario'),
      exists: existsOnDisk,
    );

    expect(resolved, isNull);
  });
}
