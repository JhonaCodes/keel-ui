import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/llm/llm.dart';
import 'package:keel_ui/src/integrations/llm/codex/codex_cli_runner.dart';

import '../support/fake_cli_process.dart';

const _spec = LlmTurnSpec(
  prompt: 'hola',
  workingDirectory: '.',
  model: 'gpt-5-codex',
  fullFileSystemAccess: false,
  effort: 'medium',
);

void main() {
  group('CodexCliRunner — cancelación', () {
    late Directory fakeBin;

    tearDown(() {
      if (fakeBin.existsSync()) fakeBin.deleteSync(recursive: true);
    });

    test(
      'un cancel pedido apenas se empieza a escuchar el turno igual lo corta '
      '(no se pierde mientras el runner arma el workspace o levanta el proceso)',
      () async {
        fakeBin = createFakeCliBin('codex', '#!/bin/sh\nsleep 5\n');

        final cancelController = StreamController<void>.broadcast();
        addTearDown(cancelController.close);
        const runner = CodexCliRunner();
        final done = Completer<void>();

        final subscription = runner
            .run(
              _spec,
              userPath: fakeCliUserPath(fakeBin),
              cancel: cancelController.stream,
            )
            .listen((_) {}, onDone: done.complete, onError: done.completeError);

        // Un solo tick del event loop: alcanza para que el generador
        // `async*` arranque y llegue a la primera línea del cuerpo (donde
        // debe suscribirse al cancel), pero no alcanza para que terminen
        // las dos operaciones reales (crear el workspace, levantar el
        // proceso) detrás de las que el bug original recién se suscribía.
        await Future<void>.delayed(Duration.zero);
        cancelController.add(null);

        await expectLater(
          done.future.timeout(const Duration(seconds: 2)),
          completes,
          reason:
              'el proceso fake duerme 5s; si el cancel se perdió, el turno '
              'no termina antes del timeout de 2s',
        );
        await subscription.cancel();
      },
    );

    test('un cancel pedido mientras el proceso ya está corriendo lo corta sin '
        'esperar a que termine solo', () async {
      fakeBin = createFakeCliBin('codex', '#!/bin/sh\nsleep 5\n');

      final cancelController = StreamController<void>.broadcast();
      addTearDown(cancelController.close);
      const runner = CodexCliRunner();
      final done = Completer<void>();
      int? pid;

      final subscription = runner
          .run(
            _spec,
            userPath: fakeCliUserPath(fakeBin),
            cancel: cancelController.stream,
            onPidKnown: (p) => pid = p,
          )
          .listen((_) {}, onDone: done.complete, onError: done.completeError);

      final started = DateTime.now();
      while (pid == null) {
        if (DateTime.now().difference(started) > const Duration(seconds: 5)) {
          fail('el proceso fake nunca arrancó');
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      cancelController.add(null);

      await expectLater(
        done.future.timeout(const Duration(seconds: 2)),
        completes,
      );
      await subscription.cancel();
    });
  });

  test(
    'resume reenvía el sandbox por -c y ya no avisa que no puede',
    () async {
      // `exec resume` no acepta `-s`, pero sí `-c sandbox_mode=...`: el
      // aviso de «reanudó sin sandbox» dejó de ser verdad y se fue.
      final fakeBin = createFakeCliBin(
        'codex',
        r'#!/bin/sh'
        '\n'
        r'printf "%s\n" "$@" > "$(dirname "$0")/argv.log"'
        '\nexit 0\n',
      );
      addTearDown(() {
        if (fakeBin.existsSync()) fakeBin.deleteSync(recursive: true);
      });
      const resumeSpec = LlmTurnSpec(
        prompt: 'seguí',
        workingDirectory: '.',
        model: 'gpt-5-codex',
        fullFileSystemAccess: true,
        effort: 'medium',
        sessionId: 'session-1',
      );

      final events = await const CodexCliRunner()
          .run(
            resumeSpec,
            userPath: fakeCliUserPath(fakeBin),
            cancel: const Stream<void>.empty(),
          )
          .toList();

      expect(events.where((event) => event['type'] == 'notice'), isEmpty);
      final argv = File('${fakeBin.path}/argv.log').readAsLinesSync();
      expect(argv, containsAllInOrder(['-c', 'sandbox_mode="danger-full-access"']));
      expect(argv.contains('-s'), isFalse);
    },
  );
}
