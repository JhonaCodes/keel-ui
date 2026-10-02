import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keel_e2e_panel/keel_e2e_panel.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/ui/view/session_e2e_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalDatabase.markUnavailable();

  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('keel-e2e-view-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => tmp.path,
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await KeelE2eHostService.instance.notifier.detach();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  testWidgets(
    'la pestaña E2E hosteá KeelE2ePanel y muestra el motor detenido con '
    'la razón de HostFailed cuando el binario no arranca',
    (tester) async {
      // Un archivo que EXISTE pero no es ejecutable: `Process.start` falla
      // rápido (permiso denegado), sin esperar los 30 s de ready timeout.
      final fakeBinary = File('${tmp.path}/not-a-real-engine');
      fakeBinary.writeAsStringSync('no soy un binario');

      final now = DateTime(2026, 10, 1);
      final project = Project(
        id: 'p-e2e',
        name: 'p-e2e',
        purpose: '',
        workingDirectory: tmp.path,
        createdAt: now,
      );
      final session = Session(id: 's-e2e', title: 'e2e', createdAt: now);

      // Todo en un solo `runAsync`: `_ensureAttached` dispara `Process.start`
      // (IO real) desde `didChangeDependencies`, y sin esto el intento queda
      // atrapado en la zona de `FakeAsync` que usan los `testWidgets`
      // normales — nunca avanza aunque se bombeen frames después.
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('es'),
            localizationsDelegates: const [
              E2eLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: E2eLocalizations.supportedLocales,
            home: Scaffold(
              body: SessionE2eView(
                project: project,
                session: session,
                debugEngineBinaryOverride: fakeBinary.path,
              ),
            ),
          ),
        );
        // Deja correr el intento de `attach()` (resuelve el dataDir, llama
        // `Process.start`, falla, actualiza el estado).
        await Future.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();
      await tester.pump();

      // RED antes del fix: `session_e2e_view.dart` mostraba un placeholder
      // propio ("todavía no está disponible") y nunca montaba
      // `KeelE2ePanel`, así que ninguno de estos finders existía.
      expect(find.byType(KeelE2ePanel), findsOneWidget);
      // `E2eStateCard` pinta la etiqueta del estado en mayúsculas.
      expect(find.text('EL MOTOR NO ESTÁ CORRIENDO'), findsOneWidget);
      expect(KeelE2eHostService.instance.notifier.data, isA<HostFailed>());
      expect(
        find.textContaining('Permission denied'),
        findsOneWidget,
        reason: 'el motivo de HostFailed llega al doctorLines de la tarjeta',
      );
    },
  );
}
