import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keel_e2e_panel/keel_e2e_panel.dart';
import 'package:result_controller/result_controller.dart';

import 'package:keel_ui/src/integrations/keel_e2e/keel_e2e.dart';
import 'package:keel_core/modules/projects/model/project.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('keel-e2e-attach-');
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
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test(
    'sin binario resuelto, ensureKeelE2eAttached devuelve '
    'KeelE2eBinaryMissing sin haber intentado arrancar ningún proceso',
    () async {
      // RED antes del fix: ni `ensureKeelE2eAttached` ni `KeelE2eBinaryMissing`
      // existían, así que esta llamada ni compilaba. Sin
      // `debugEngineBinaryOverride`, la resolución real cae en este entorno
      // de test: el test runner no corre desde una `.app` que traiga el
      // motor embebido.
      final project = Project(
        id: 'p',
        name: 'p',
        purpose: '',
        workingDirectory: '/tmp',
        createdAt: DateTime(2026, 10, 1),
      );

      final result = await ensureKeelE2eAttached(
        project: project,
        sessionId: 's',
      );

      expect(result, isA<Err<EngineConnection, KeelE2eAttachFailure>>());
      final failure = (result as Err<EngineConnection, KeelE2eAttachFailure>)
          .error;
      expect(failure, isA<KeelE2eBinaryMissing>());
      expect(failure.message, contains('Vuelve a compilar Keel'));
    },
  );

  // "Iniciar motor" (architecture §9's tarjeta de motor apagado, antes de
  // cualquier sesión): `SessionE2eView` llama esto en vez de
  // `ensureKeelE2eAttached` cuando no hay sesión todavía — deja el host
  // listo sin arrancar nada.
  test(
    'prepareKeelE2eHost deja el config listo para start(), sin arrancar '
    'ningún proceso por su cuenta',
    () async {
      addTearDown(KeelE2eHostService.instance.notifier.detach);
      final project = Project(
        id: 'p',
        name: 'p',
        purpose: '',
        workingDirectory: '/tmp',
        createdAt: DateTime(2026, 10, 1),
      );

      // Un fixture que lee el handshake y se queda esperando (nunca
      // imprime `KEEL_E2E_READY`): sigue vivo para que `_start` pueda
      // escribirle a stdin sin un "Broken pipe" — algo como `true`, que
      // sale enseguida, no sirve acá.
      final script = File('${tmp.path}/fixture_silent.sh');
      script.writeAsStringSync(
        '#!/bin/sh\n'
        'read -r handshake\n'
        'while read -r _line; do :; done\n'
        'exit 0\n',
      );
      Process.runSync('chmod', ['+x', script.path]);

      final result = await prepareKeelE2eHost(
        project: project,
        sessionId: '',
        debugEngineBinaryOverride: script.path,
      );

      expect(result, isA<Ok<void, KeelE2eAttachFailure>>());
      expect(
        KeelE2eHostService.instance.notifier.data,
        isA<HostIdle>(),
        reason: 'prepare() nunca debe arrancar el proceso por su cuenta',
      );

      // El oráculo real: `start()` solo puede llegar a `HostStarting` (y
      // ahí quedarse esperando READY) si `prepare()` de verdad guardó un
      // config — su `_fail` de "no hay configuración" resuelve antes de
      // tocar ningún proceso, mucho más rápido que esta espera.
      unawaited(KeelE2eHostService.instance.notifier.start());
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(
        KeelE2eHostService.instance.notifier.data,
        isA<HostStarting>(),
        reason:
            'start() debe usar el config de prepare(), no fallar con '
            '"no hay configuración todavía"',
      );
    },
  );
}
