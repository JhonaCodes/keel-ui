import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/llm/src/cli_cancel_guard.dart';

void main() {
  group('CliCancelGuard', () {
    test('un cancel llegado después de attach() mata el proceso', () async {
      final cancelController = StreamController<void>.broadcast();
      addTearDown(cancelController.close);
      final guard = CliCancelGuard(cancelController.stream);
      final process = await Process.start('sleep', ['30']);
      addTearDown(() => process.kill());

      guard.attach(process);
      expect(guard.cancelled, isFalse);

      cancelController.add(null);
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 2),
      );

      expect(guard.cancelled, isTrue);
      expect(exitCode, isNot(0));
      await guard.dispose();
    });

    test('un cancel llegado ANTES de attach() no se pierde: mata igual al '
        'adjuntar el proceso', () async {
      final cancelController = StreamController<void>.broadcast();
      addTearDown(cancelController.close);
      final guard = CliCancelGuard(cancelController.stream);

      // El cancel llega mientras el runner todavía arma el proceso — no
      // hay nada que matar todavía.
      cancelController.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(guard.cancelled, isTrue);

      final process = await Process.start('sleep', ['30']);
      addTearDown(() => process.kill());
      guard.attach(process);

      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 2),
      );
      expect(exitCode, isNot(0));
      await guard.dispose();
    });

    test('sin cancel, el proceso adjuntado sigue vivo', () async {
      final cancelController = StreamController<void>.broadcast();
      addTearDown(cancelController.close);
      final guard = CliCancelGuard(cancelController.stream);
      final process = await Process.start('sleep', ['30']);

      guard.attach(process);
      expect(guard.cancelled, isFalse);

      process.kill();
      await process.exitCode;
      await guard.dispose();
    });

    test(
      'dispose() corta la suscripción: un cancel posterior no hace nada',
      () async {
        final cancelController = StreamController<void>.broadcast();
        addTearDown(cancelController.close);
        final guard = CliCancelGuard(cancelController.stream);
        final process = await Process.start('sleep', ['30']);
        addTearDown(() => process.kill());
        guard.attach(process);

        await guard.dispose();
        cancelController.add(null);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(guard.cancelled, isFalse);
        expect(
          await process.exitCode
              .timeout(const Duration(seconds: 1))
              .catchError((_) => -1),
          -1,
        );
      },
    );
  });
}
