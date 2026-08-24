import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:keel_ui/src/integrations/app_update/app_update.dart';

/// La salida real de `git log --format=%h\x1f%s\x1f%cI` con dos commits.
const _log =
    '5189713\x1ffix: el cuadro de una consulta mide lo que dice\x1f2026-08-23T16:20:56+12:00\n'
    '0361953\x1ffeat: poder decir que no\x1f2026-08-23T11:02:10+12:00';

KeelVersion _version({
  String branch = 'main',
  bool dirty = false,
  bool hasUpstream = true,
  List<KeelCommit> incoming = const [],
  DateTime? at,
  DateTime? builtAt,
}) => KeelVersion(
  branch: branch,
  head: '5189713',
  subject: 'fix: algo',
  at: at,
  builtAt: builtAt,
  dirty: dirty,
  hasUpstream: hasUpstream,
  incoming: incoming,
);

void main() {
  group('releases instalables', () {
    const sha =
        'd490c46d93c5c04bdf304a735b128ff02d307c5b963ea1f9ca2ba9196969a694';

    test('una versión semántica posterior enciende la descarga', () async {
      final status = await readInstalledRelease(
        packageInfo: PackageInfo(
          appName: 'Keel',
          packageName: 'com.jhonacode.keelUi',
          version: '1.4.19',
          buildNumber: '41',
        ),
        client: MockClient(
          (_) async => http.Response(
            '{'
            '"version":"1.5.0",'
            '"build":42,'
            '"downloadUrl":"https://jhonacode.com/keel/Keel-1.5.0-macos-universal.dmg",'
            '"sha256":"$sha",'
            '"publishedAt":"2026-08-25T10:00:00Z"'
            '}',
            200,
          ),
        ),
      );

      expect(status.current?.pubspecValue, '1.4.19+41');
      expect(status.latest?.release.pubspecValue, '1.5.0+42');
      expect(status.updateAvailable, isTrue);
    });

    test('un fallo del canal conserva visible la versión instalada', () async {
      final status = await readInstalledRelease(
        packageInfo: PackageInfo(
          appName: 'Keel',
          packageName: 'com.jhonacode.keelUi',
          version: '2.3.4',
          buildNumber: '57',
        ),
        client: MockClient((_) async => http.Response('no disponible', 503)),
      );

      expect(status.displayVersion, '2.3.4');
      expect(status.updateAvailable, isFalse);
      expect(status.error, contains('HTTP 503'));
    });

    test('una descarga nueva no enciende también el aviso de Máquina', () {
      final state = AppUpdateState(
        release: InstalledReleaseStatus(
          current: const ReleaseVersion(major: 1, minor: 0, patch: 0, build: 1),
          latest: KeelReleaseManifest(
            release: const ReleaseVersion(
              major: 1,
              minor: 0,
              patch: 1,
              build: 2,
            ),
            downloadUrl: Uri.parse(
              'https://jhonacode.com/keel/Keel-1.0.1-macos-universal.dmg',
            ),
            sha256: sha,
            publishedAt: DateTime.utc(2026, 8, 25),
          ),
        ),
      );

      expect(state.release.updateAvailable, isTrue);
      expect(state.pending, isFalse);
    });
  });

  group('leer el log', () {
    test('un commit por línea, con su fecha', () {
      final commits = parseCommitLog(_log);

      expect(commits, hasLength(2));
      expect(commits.first.sha, '5189713');
      expect(
        commits.first.subject,
        'fix: el cuadro de una consulta mide lo que dice',
      );
      expect(commits.last.at.year, 2026);
    });

    test('una línea que no se entiende se saltea, no tira todo', () {
      final commits = parseCommitLog('basura\n$_log');
      expect(commits, hasLength(2));
    });

    test('sin commits nuevos, la lista está vacía', () {
      expect(parseCommitLog(''), isEmpty);
    });
  });

  group('encontrar el repo', () {
    test('sube hasta la carpeta que tiene el pubspec de Keel', () {
      final root = keelRootAbove(
        '/repos/keel-ui/build/macos/Build/Products/Debug/Keel.app/Contents/MacOS',
        (dir) => dir == '/repos/keel-ui',
      );
      expect(root, '/repos/keel-ui');
    });

    test('si no está, no inventa una ruta', () {
      final root = keelRootAbove('/Aplicaciones/Keel.app/Contents/MacOS', (_) {
        return false;
      });
      expect(root, '');
    });

    test('no busca hasta el infinito', () {
      var mirados = 0;
      keelRootAbove('/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o', (_) {
        mirados++;
        return false;
      }, depth: 3);
      expect(mirados, 3);
    });
  });

  group('qué impide actualizar', () {
    test('sin repo al lado no hay nada que traer', () {
      final plan = KeelUpdatePlan(
        source: const KeelSource(),
        version: _version(),
      );
      expect(plan.blockers, hasLength(1));
      expect(plan.blockers.single, contains('no tiene su código al lado'));
      expect(plan.canRun, isFalse);
    });

    test('cambios sin commitear: un pull con eso encima se niega', () {
      final plan = KeelUpdatePlan(
        source: const KeelSource(root: '/repos/keel-ui'),
        version: _version(dirty: true),
      );
      expect(plan.blockers.single, contains('sin commitear'));
    });

    test('una rama que no sigue a nadie no tiene con qué compararse', () {
      final plan = KeelUpdatePlan(
        source: const KeelSource(root: '/repos/keel-ui'),
        version: _version(hasUpstream: false),
      );
      expect(plan.blockers.single, contains('no sigue a ninguna'));
    });

    test('al día no es un bloqueo, pero tampoco hay qué traer', () {
      final plan = KeelUpdatePlan(
        source: const KeelSource(root: '/repos/keel-ui'),
        version: _version(),
      );
      expect(plan.blockers, isEmpty);
      expect(plan.canRun, isFalse);
      expect(plan.headline, 'Estás en la última.');
    });

    test('con commits nuevos y nada en contra, se puede', () {
      final plan = KeelUpdatePlan(
        source: const KeelSource(root: '/repos/keel-ui'),
        version: _version(incoming: parseCommitLog(_log)),
      );
      expect(plan.canRun, isTrue);
      expect(plan.headline, contains('2 commits nuevos'));
    });

    test('reconstruir con turnos vivos los corta por la mitad', () {
      final plan = KeelUpdatePlan(
        source: const KeelSource(root: '/repos/keel-ui'),
        version: _version(),
        running: 2,
      );
      // Traer commits sí; cerrar la app, no.
      expect(plan.blockers, isEmpty);
      expect(plan.canRelaunch, isFalse);
    });
  });

  group('estar corriendo código viejo', () {
    test('el binario más viejo que el commit es código sin construir', () {
      final version = _version(
        at: DateTime(2026, 8, 23, 16),
        builtAt: DateTime(2026, 8, 23, 9),
      );
      expect(version.stale, isTrue);
    });

    test('construido después del commit es estar al día de verdad', () {
      final version = _version(
        at: DateTime(2026, 8, 23, 9),
        builtAt: DateTime(2026, 8, 23, 16),
      );
      expect(version.stale, isFalse);
    });

    test('sin fecha del binario no se acusa a nadie', () {
      expect(_version(at: DateTime(2026, 8, 23)).stale, isFalse);
    });

    test('el aviso también sale con el repo al día', () {
      final plan = KeelUpdatePlan(
        source: const KeelSource(root: '/repos/keel-ui'),
        version: _version(
          at: DateTime(2026, 8, 23, 16),
          builtAt: DateTime(2026, 8, 23, 9),
        ),
      );
      expect(plan.headline, contains('construcción anterior'));
    });
  });

  group('el comando de reconstruir', () {
    test('entra en el shell tal cual, con la ruta entre comillas', () {
      expect(
        rebuildCommand('/repos/keel-ui'),
        "cd '/repos/keel-ui' && flutter run -d macos",
      );
    });

    test('una comilla en la ruta no rompe el comando', () {
      // `/repos/jhona's/keel-ui` cierra la comilla del `cd` si no se escapa,
      // y lo que sigue lo interpreta el shell.
      expect(rebuildCommand("/repos/jhona's/keel-ui"), contains(r"'\''"));
    });
  });
}
