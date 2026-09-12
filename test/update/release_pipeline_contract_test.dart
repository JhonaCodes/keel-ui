import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/integrations/app_update/app_update.dart';
import 'package:keel_ui/src/modules/agents/ui/view/agent_rail.dart';

void main() {
  setUpAll(LocalDatabase.markUnavailable);

  group('versionado de compilaciones', () {
    test('CI conserva la versión del tag con --no-bump', () async {
      final before = await File('pubspec.yaml').readAsString();
      final current = RegExp(
        r'^version:\s*(\S+)',
        multiLine: true,
      ).firstMatch(before)!.group(1)!;
      final result = await Process.run('scripts/build_macos_release.sh', [
        '--dry-run',
        '--no-bump',
        '--output-dir',
        'build/release',
      ]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect('${result.stdout}', contains('Próxima compilación: $current'));
      expect(await File('pubspec.yaml').readAsString(), before);
    });

    Future<String> nextVersion(String current) async {
      final result = await Process.run('dart', [
        'run',
        'tool/release_version.dart',
        'next',
        current,
      ]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      return '${result.stdout}'.trim();
    }

    test('cada compilación incrementa patch y build', () async {
      expect(await nextVersion('1.4.18+41'), '1.4.19+42');
    });

    test('al llegar a veinte hace rollover de minor', () async {
      expect(await nextVersion('1.4.19+41'), '1.5.0+42');
    });

    test('el major nunca cambia automáticamente', () async {
      expect(await nextVersion('7.19.19+99'), '7.20.0+100');
    });

    test(
      'el script permite anticipar la release sin modificar pubspec',
      () async {
        final before = await File('pubspec.yaml').readAsString();
        final current = RegExp(
          r'^version:\s*(\S+)',
          multiLine: true,
        ).firstMatch(before)!.group(1)!;
        final expected = await nextVersion(current);
        final result = await Process.run('scripts/build_macos_release.sh', [
          '--dry-run',
        ]);

        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect('${result.stdout}', contains('Próxima compilación: $expected'));
        expect(await File('pubspec.yaml').readAsString(), before);
      },
    );
  });

  testWidgets('la versión instalada vive debajo de Ajustes', (tester) async {
    AppUpdateService.instance.notifier.updateState(
      AppUpdateState(
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
            sha256:
                'd490c46d93c5c04bdf304a735b128ff02d307c5b963ea1f9ca2ba9196969a694',
            publishedAt: DateTime.utc(2026, 8, 25),
          ),
        ),
      ),
    );
    addTearDown(
      () => AppUpdateService.instance.notifier.updateState(
        const AppUpdateState(),
      ),
    );
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        // The widgets under test read AppLocalizations; without the
        // delegates `AppLocalizations.of` returns null and build throws.
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AgentRail(
            onOpenProfiles: () async {},
            onOpenSkills: () async {},
            onOpenRules: () async {},
            onOpenHooks: () async {},
            onOpenTools: () async {},
            onOpenSecrets: () async {},
            onOpenMcpServers: () async {},
            onOpenKnowledge: () async {},
            onOpenWorkflows: () async {},
            onOpenBoards: () async {},
            onOpenMachine: () async {},
          ),
        ),
      ),
    );
    await tester.pump();

    final settings = find.text('Ajustes');
    final version = find.byKey(const Key('keel-app-version'));
    expect(settings, findsOneWidget);
    expect(version, findsOneWidget);
    expect(find.text('v1.0.0'), findsOneWidget);
    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
    expect(
      tester.getTopLeft(version).dy,
      greaterThan(tester.getTopLeft(settings).dy),
    );
  });
}
