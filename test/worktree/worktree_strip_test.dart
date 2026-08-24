import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/integrations/git_worktree/git_worktree.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/l10n/generated/app_localizations.dart';

final _epoch = DateTime(2026, 8, 23);

Future<void> _git(List<String> args, String cwd) async {
  final result = await Process.run('git', args, workingDirectory: cwd);
  if (result.exitCode != 0) {
    fail('git ${args.join(' ')} falló:\n${result.stdout}\n${result.stderr}');
  }
}

Project _project(String dir) => Project(
  id: 'p',
  name: 'proyecto',
  purpose: '',
  workingDirectory: dir,
  createdAt: _epoch,
);

Widget _app(Project project) => MaterialApp(
  locale: const Locale('es'),
  theme: buildAppTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: WorktreeStrip(project: project)),
);

/// El panel en el ancho con el que se abre de verdad. Es el que importa:
/// abajo hay rutas largas y párrafos, y un desborde solo aparece a un ancho
/// concreto.
Widget _panel(Project project) => MaterialApp(
  locale: const Locale('es'),
  theme: buildAppTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Center(
      child: SizedBox(width: 640, child: WorktreePanel(project: project)),
    ),
  ),
);

void main() {
  late Directory tmp;
  late String main_;
  late String aparte;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('keel-strip');
    final root = tmp.resolveSymbolicLinksSync();
    main_ = '$root/principal';
    aparte = '$root/aparte';
    Directory(main_).createSync();
    await _git(['init', '-q', '-b', 'main', '.'], main_);
    await _git(['config', 'user.email', 'test@keel.local'], main_);
    await _git(['config', 'user.name', 'keel test'], main_);
    await _git(['config', 'commit.gpgsign', 'false'], main_);
    File('$main_/a.txt').writeAsStringSync('uno\n');
    await _git(['add', '-A'], main_);
    await _git(['commit', '-qm', 'primero'], main_);
    await _git(['worktree', 'add', '-q', aparte, '-b', 'feat/paralelo'], main_);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  testWidgets('en el principal no ocupa ni un píxel', (tester) async {
    await tester.runAsync(
      () => WorktreeService.instance.notifier.ensure(main_, force: true),
    );

    await tester.pumpWidget(_app(_project(main_)));
    await tester.pump();

    expect(find.textContaining('Worktree aparte'), findsNothing);
    expect(find.text('Unificar'), findsNothing);
    expect(tester.getSize(find.byType(WorktreeStrip)).height, 0);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('en uno de al lado avisa y nombra la rama', (tester) async {
    await tester.runAsync(
      () => WorktreeService.instance.notifier.ensure(aparte, force: true),
    );

    await tester.pumpWidget(_app(_project(aparte)));
    await tester.pump();

    expect(find.textContaining('Worktree aparte'), findsOneWidget);
    expect(find.textContaining('feat/paralelo'), findsOneWidget);
    // El nombre de la carpeta del principal, para saber a dónde volvés.
    expect(find.textContaining('principal'), findsOneWidget);
    expect(find.text('Unificar'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('el panel dice qué va a pasar antes de tocar nada', (
    tester,
  ) async {
    final project = _project(aparte);
    await tester.runAsync(
      () => WorktreeService.instance.notifier.prepare(project),
    );

    await tester.pumpWidget(_panel(project));
    await tester.pump();

    expect(find.text('Worktree aparte'), findsOneWidget);
    expect(find.text('QUÉ VA A PASAR'), findsOneWidget);
    expect(find.textContaining('BORRA la carpeta del disco'), findsOneWidget);
    expect(find.text('Unificar en el principal'), findsOneWidget);

    // Sin trabas, el botón está vivo: es un repo limpio recién armado.
    final boton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(boton.onPressed, isNotNull);

    // Y nada se tocó por mirarlo.
    expect(Directory(aparte).existsSync(), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    WorktreeService.instance.notifier.forget();
  });
}
