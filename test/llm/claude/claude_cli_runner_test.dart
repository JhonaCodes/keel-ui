import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/llm/llm.dart';
import 'package:keel_ui/src/integrations/llm/claude/claude_cli_runner.dart';

import '../support/fake_cli_process.dart';

const _spec = LlmTurnSpec(
  prompt: 'hola',
  workingDirectory: '.',
  model: 'sonnet',
  fullFileSystemAccess: false,
  effort: 'medium',
);

void main() {
  group('ClaudeCliRunner — cancelación', () {
    late Directory fakeBin;

    tearDown(() {
      if (fakeBin.existsSync()) fakeBin.deleteSync(recursive: true);
    });

    test(
      'un cancel pedido apenas se empieza a escuchar el turno igual lo corta '
      '(no se pierde mientras el runner arma el workspace o levanta el proceso)',
      () async {
        fakeBin = createFakeCliBin('claude', '#!/bin/sh\nsleep 5\n');

        final cancelController = StreamController<void>.broadcast();
        addTearDown(cancelController.close);
        const runner = ClaudeCliRunner();
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
      fakeBin = createFakeCliBin('claude', '#!/bin/sh\nsleep 5\n');

      final cancelController = StreamController<void>.broadcast();
      addTearDown(cancelController.close);
      const runner = ClaudeCliRunner();
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

  group('ClaudeCliRunner — stdin', () {
    late Directory fakeBin;

    tearDown(() {
      if (fakeBin.existsSync()) fakeBin.deleteSync(recursive: true);
    });

    test('cierra el stdin del CLI: sin la espera de 3s ni su aviso en stderr',
        () async {
      // `claude -p` con stdin que no es TTY espera datos unos segundos y, al
      // vencer, escribe "Warning: no stdin data received..." en stderr. Con
      // un exit distinto de cero, ese stderr era el "error" que veía el
      // usuario en el hilo, y cada turno pagaba la espera.
      // POSIX a propósito: el `read -t` de bash devuelve >128 al vencer en
      // bash 5 y 1 en el bash 3.2 de macOS, así que un fake con `-t` pasaba
      // sin probar nada. Acá se mira si un `read` en segundo plano sigue
      // vivo tras un segundo: con stdin cerrado termina al instante.
      fakeBin = createFakeCliBin('claude', '''#!/bin/sh
exec 3<&0
( read -r _line <&3 ) &
pid=\$!
sleep 1
if kill -0 "\$pid" 2>/dev/null; then
  echo "Warning: no stdin data received in 1s, proceeding without it." >&2
  kill "\$pid" 2>/dev/null
fi
exit 1
''');
      const runner = ClaudeCliRunner();

      final events = await runner
          .run(
            _spec,
            userPath: fakeCliUserPath(fakeBin),
            cancel: const Stream<void>.empty(),
          )
          .toList();

      final failure = events.singleWhere((event) => event['type'] == 'failure');
      expect(failure['message'], isNot(contains('no stdin data')));
    });
  });
}
