import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/claude_stream_events.dart';
import 'package:keel_ui/src/integrations/llm/src/cli_turn_stream.dart';
import 'package:keel_ui/src/integrations/task_runner/task_runner.dart';

/// Lo que el CLI escribe cuando se queda sin turnos agénticos: dice cómo
/// terminó en el stream Y sale con código distinto de cero.
const _maxTurnsResult = {
  'type': 'result',
  'subtype': 'error_max_turns',
  'is_error': true,
  'total_cost_usd': 0.1,
  'duration_ms': 900,
  'num_turns': 12,
};

Future<List<Map<String, dynamic>>> _events({
  required List<Map<String, dynamic>> stdout,
  required int exitCode,
  String stderr = '',
}) => cliTurnEvents(
  lines: Stream.fromIterable(stdout.map(jsonEncode)),
  read: ClaudeStreamReader().read,
  stderr: Future.value(stderr),
  exitCode: Future.value(exitCode),
  provider: 'claude',
).toList();

void main() {
  group('cliTurnEvents', () {
    test('el tope de turnos cierra el turno y NO emite falla', () async {
      final events = await _events(stdout: [_maxTurnsResult], exitCode: 1);

      // Lo que arruinaba el caso: el código de salida del tope llegaba
      // ADEMÁS como falla de proveedor, el turno quedaba fallido y el nodo
      // nunca llegaba a decir cómo quedó.
      expect(
        events.where((event) => event['type'] == 'failure'),
        isEmpty,
        reason: 'el tope ya se reportó in-band con su `result`',
      );

      final turn =
          TaskEvent.fromMessage(
                events.firstWhere((event) => event['type'] == 'turnCompleted'),
              )
              as TaskTurnCompleted;
      expect(turn.hitTurnCap, isTrue);
    });

    test('un error que NO es el tope no se traga su causa', () async {
      // El `result` dice QUE falló, pero el porqué está en stderr: acá el
      // fallback es la única causa que hay, y suprimirlo dejaba la huella
      // del hallazgo vacía y la fila de Fallas sin escribir.
      final events = await _events(
        stdout: const [
          {
            'type': 'result',
            'subtype': 'error_during_execution',
            'is_error': true,
            'total_cost_usd': 0.1,
            'duration_ms': 900,
          },
        ],
        exitCode: 1,
        stderr: 'Error: API request failed with status 529',
      );

      expect(events.last, {
        'type': 'failure',
        'message': 'Error: API request failed with status 529',
      });
    });

    test('un crash sin `result` previo sí emite la falla', () async {
      final events = await _events(
        stdout: const [],
        exitCode: 1,
        stderr: 'claude: command failed',
      );

      expect(events, [
        {'type': 'failure', 'message': 'claude: command failed'},
      ]);
    });

    test('sin stderr, la falla del crash lleva el código', () async {
      final events = await _events(stdout: const [], exitCode: 127);

      expect(events.single['message'], 'claude terminó con código 127');
    });

    test('un turno que terminó bien no emite falla', () async {
      final events = await _events(
        stdout: [
          {
            'type': 'result',
            'subtype': 'success',
            'is_error': false,
            'total_cost_usd': 0.1,
            'duration_ms': 900,
          },
        ],
        exitCode: 0,
      );

      expect(events.where((event) => event['type'] == 'failure'), isEmpty);
    });
  });
}
