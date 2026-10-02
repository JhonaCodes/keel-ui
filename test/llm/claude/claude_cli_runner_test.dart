import 'dart:async';
import 'dart:convert';
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

/// A `claude` that behaves like CLI 2.1.280 with `--input-format
/// stream-json`: the prompt is the first stdin line, a line written while a
/// tool runs enters the same turn, and the process leaves only when its stdin
/// closes. Each stdin line lands in `stdin.log` next to the script. Python and
/// `select` so that a missing line times out instead of hanging the test.
const _steerableCli = r'''#!/usr/bin/env python3
import json, select, sys
from pathlib import Path

log = Path(__file__).with_name('stdin.log')

def line(timeout):
    ready, _, _ = select.select([sys.stdin], [], [], timeout)
    if not ready:
        return None
    return sys.stdin.readline() or None

def emit(event):
    print(json.dumps(event), flush=True)

with log.open('a') as out:
    out.write(line(5) or '<eof>\n')
emit({'type': 'system', 'subtype': 'init', 'session_id': 's1', 'model': 'sonnet'})
emit({'type': 'assistant', 'message': {'content': [
    {'type': 'tool_use', 'id': 't1', 'name': 'Bash', 'input': {'command': 'sleep 1'}}]}})
second = line(3)
with log.open('a') as out:
    out.write(second or '<none>\n')
text = 'GOT-IT' if second else 'NO-STEER'
emit({'type': 'assistant', 'message': {'content': [{'type': 'text', 'text': text}]}})
emit({'type': 'result', 'subtype': 'success', 'is_error': False, 'result': text,
      'total_cost_usd': 0.01, 'duration_ms': 5})
while True:
    rest = line(5)
    if rest is None:
        break
    with log.open('a') as out:
        out.write(rest)
''';

/// A stdin line as the fake logged it: the JSON it got, or its marker
/// (`<none>`, `<eof>`) when nothing arrived.
Object? _decoded(String line) {
  try {
    return jsonDecode(line);
  } on FormatException {
    return line;
  }
}

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

  group('ClaudeCliRunner — mensaje a mitad de turno', () {
    late Directory fakeBin;

    tearDown(() {
      if (fakeBin.existsSync()) fakeBin.deleteSync(recursive: true);
    });

    test('el mensaje entra por stdin con prioridad next, el turno sigue vivo y '
        'el stdin se cierra al primer result', () async {
      fakeBin = createFakeCliBin('claude', _steerableCli);
      final steer = StreamController<String>();
      // Sin await: un stream que nadie escuchó no termina de cerrarse.
      addTearDown(() => unawaited(steer.close()));
      const runner = ClaudeCliRunner();
      final events = <LlmEvent>[];
      final started = DateTime.now();

      await for (final event in runner.run(
        _spec,
        userPath: fakeCliUserPath(fakeBin),
        cancel: const Stream<void>.empty(),
        steer: steer.stream,
      )) {
        events.add(event);
        // Como el usuario: escribe mientras el agente está en una
        // herramienta.
        if (event['type'] == 'toolUse') steer.add('cambio de rumbo');
      }

      final stdinLines = File('${fakeBin.path}/stdin.log').readAsLinesSync();
      expect(_decoded(stdinLines[0]), {
        'type': 'user',
        'message': {'role': 'user', 'content': 'hola'},
      });
      expect(_decoded(stdinLines[1]), {
        'type': 'user',
        'message': {'role': 'user', 'content': 'cambio de rumbo'},
        'priority': 'next',
      });
      expect(
        events
            .where((event) => event['type'] == 'assistantText')
            .map((event) => event['text']),
        ['GOT-IT'],
      );
      expect(events.where((event) => event['type'] == 'steerDelivered'), [
        {'type': 'steerDelivered', 'text': 'cambio de rumbo'},
      ]);
      expect(events.where((event) => event['type'] == 'failure'), isEmpty);
      // El fake espera 5 s a que se cierre su stdin después del `result`:
      // terminar antes prueba que el runner lo cerró al ver el `result`.
      expect(
        DateTime.now().difference(started),
        lessThan(const Duration(seconds: 4)),
      );
    });

    test('un mensaje que llega después del result no se da por entregado: '
        'sin acuse, quien lo mandó lo devuelve a la cola', () async {
      fakeBin = createFakeCliBin('claude', _steerableCli);
      final steer = StreamController<String>();
      addTearDown(() => unawaited(steer.close()));
      const runner = ClaudeCliRunner();
      final events = <LlmEvent>[];

      await for (final event in runner.run(
        _spec,
        userPath: fakeCliUserPath(fakeBin),
        cancel: const Stream<void>.empty(),
        steer: steer.stream,
      )) {
        events.add(event);
        if (event['type'] == 'turnCompleted') steer.add('tarde');
      }

      expect(
        events.where((event) => event['type'] == 'steerDelivered'),
        isEmpty,
      );
      expect(
        File('${fakeBin.path}/stdin.log').readAsStringSync(),
        isNot(contains('tarde')),
      );
    });
  });

  group('ClaudeCliRunner — stdin', () {
    late Directory fakeBin;

    tearDown(() {
      if (fakeBin.existsSync()) fakeBin.deleteSync(recursive: true);
    });

    test('el prompt llega por stdin: el CLI no espera datos ni deja su aviso '
        'en stderr', () async {
      // `claude -p` con stdin que no es TTY espera datos unos segundos y, al
      // vencer, escribe "Warning: no stdin data received..." en stderr. Con
      // un exit distinto de cero, ese stderr era el "error" que veía el
      // usuario en el hilo, y cada turno pagaba la espera. Hoy el prompt es
      // la primera línea del stdin, así que el `read` del CLI vuelve al
      // instante.
      // POSIX a propósito: el `read -t` de bash devuelve >128 al vencer en
      // bash 5 y 1 en el bash 3.2 de macOS, así que un fake con `-t` pasaba
      // sin probar nada. Acá se mira si un `read` en segundo plano sigue
      // vivo tras un segundo.
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
