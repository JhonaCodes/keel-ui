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

  test('finds the engine embedded in the installed app', () {
    final app = p.join(tmp.path, 'Applications', 'Keel.app');
    final embedded = p.join(
      app,
      'Contents',
      'Resources',
      'keel_e2e',
      'bin',
      'keel_e2e',
    );
    File(embedded).createSync(recursive: true);

    final resolved = KeelE2eBinary.resolve(
      resolvedExecutablePath: p.join(app, 'Contents', 'MacOS', 'Keel'),
      exists: existsOnDisk,
    );

    expect(resolved, embedded);
  });

  test('a bundle without the engine resolves to null, never elsewhere', () {
    // A checkout of keel-e2e next to keel-ui no longer counts: only what
    // the build embedded in the app does.
    File(
      p.join(
        tmp.path,
        'KEEL',
        'keel-e2e',
        'build',
        'bundle',
        'bin',
        'keel_e2e',
      ),
    ).createSync(recursive: true);
    final exe = p.join(
      tmp.path,
      'KEEL',
      'keel-ui',
      'build',
      'macos',
      'Build',
      'Products',
      'Debug',
      'Keel.app',
      'Contents',
      'MacOS',
      'Keel',
    );

    final resolved = KeelE2eBinary.resolve(
      resolvedExecutablePath: exe,
      exists: existsOnDisk,
    );

    expect(resolved, isNull);
  });

  test('outside a macOS bundle, resolves to null', () {
    final resolved = KeelE2eBinary.resolve(
      resolvedExecutablePath: p.join(tmp.path, 'solo', 'un', 'binario'),
      exists: existsOnDisk,
    );

    expect(resolved, isNull);
  });
}
