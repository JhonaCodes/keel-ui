import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/integrations/system_prompt/system_prompt.dart';
import 'package:keel_ui/src/integrations/workspace_roots/workspace_roots.dart';

void main() {
  LocalDatabase.markUnavailable();

  group('volúmenes montados', () {
    test('deja afuera lo que no existe', () {
      final roots = mountedVolumeRoots(
        platformRoots: ['/Volumes/Data', '/Volumes/Fantasma'],
        exists: (path) => path == '/Volumes/Data',
      );

      expect(roots, ['/Volumes/Data']);
    });

    test('no repite ni se queda con vacíos', () {
      final roots = mountedVolumeRoots(
        platformRoots: ['/mnt/a', '  ', '/mnt/a', '/mnt/b'],
        exists: (_) => true,
      );

      expect(roots, ['/mnt/a', '/mnt/b']);
    });

    test('preguntarle al sistema de verdad no explota', () {
      expect(mountedVolumeRoots(), isA<List<String>>());
    });
  });

  group('la clave de una raíz', () {
    test('sobrevive a barras, espacios y acentos', () {
      final root = WorkspaceRoot(
        path: '/Volumes/Data/Mis Proyectos/ñandú',
        lastUsedAt: DateTime.utc(2026, 8, 27),
      );

      expect(root.id, matches(RegExp(r'^[A-Za-z0-9_]+$')));
      expect(root.toJson()['id'], root.id);
    });

    test('es la misma en dos corridas y distinta por disco', () {
      final at = DateTime.utc(2026, 8, 27);
      const uno = '/Volumes/Data/keel-ui';
      const otro = '/Users/jhona/keel-ui';

      expect(
        WorkspaceRoot(path: uno, lastUsedAt: at).id,
        WorkspaceRoot(
          path: uno,
          lastUsedAt: at.add(const Duration(days: 1)),
        ).id,
      );
      expect(
        WorkspaceRoot(path: uno, lastUsedAt: at).id,
        isNot(WorkspaceRoot(path: otro, lastUsedAt: at).id),
      );
    });

    test('el viaje de ida y vuelta conserva la ruta', () {
      final root = WorkspaceRoot(
        path: '/mnt/discoB/proyecto',
        lastUsedAt: DateTime.utc(2026, 8, 27),
      );

      expect(WorkspaceRoot.fromJson(root.toJson()), root);
    });
  });

  group('las carpetas recientes', () {
    final roots = WorkspaceRootsService.instance.notifier;

    setUp(() async {
      await roots.ready;
      for (final path in [...roots.recentPaths]) {
        await roots.forget(path);
      }
    });

    test('la última usada queda primera y no se duplica', () async {
      final a = Directory.systemTemp.createTempSync('keel_a').path;
      final b = Directory.systemTemp.createTempSync('keel_b').path;
      addTearDown(() {
        Directory(a).deleteSync(recursive: true);
        Directory(b).deleteSync(recursive: true);
      });

      await roots.remember(a);
      await roots.remember(b);
      await roots.remember(a);

      expect(roots.recentPaths, [a, b]);
      expect(roots.lastUsedPath, a);
    });

    test('una carpeta que no existe no se anota', () async {
      await roots.remember('/no/existe/en/esta/maquina');

      expect(roots.recentPaths, isEmpty);
    });
  });

  group('el prompt de rutas conocidas', () {
    test('sin nada que decir no ocupa lugar en el prompt', () {
      expect(knownRootsPrompt(projects: const [], otherRoots: const []), '');
    });

    test('nombra cada proyecto con su ruta absoluta', () {
      final prompt = knownRootsPrompt(
        projects: [(name: 'keel-ui', path: '/Volumes/Data/keel-ui')],
        otherRoots: const ['/Volumes/Data/experimentos'],
      );

      expect(prompt, contains('- keel-ui: /Volumes/Data/keel-ui'));
      expect(prompt, contains('- /Volumes/Data/experimentos'));
      expect(prompt, contains('preguntá dónde'));
    });
  });
}
