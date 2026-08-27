import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/claude_stream_events.dart';
import 'package:keel_ui/src/core/services/turn_usage.dart';

/// Un evento `assistant` con el `usage` de UNA llamada.
Map<String, dynamic> llamada({
  required int input,
  required int cacheRead,
  required int cacheCreate,
  String? parentToolUseId,
}) => {
  'type': 'assistant',
  'parent_tool_use_id': ?parentToolUseId,
  'message': {
    'content': [
      {'type': 'text', 'text': 'algo'},
    ],
    'usage': {
      'input_tokens': input,
      'cache_read_input_tokens': cacheRead,
      'cache_creation_input_tokens': cacheCreate,
      'output_tokens': 5,
    },
  },
};

Map<String, dynamic> resultado({
  required int input,
  required int cacheRead,
  required int cacheCreate,
  Map<String, dynamic>? modelUsage,
}) => {
  'type': 'result',
  'is_error': false,
  'usage': {
    'input_tokens': input,
    'cache_read_input_tokens': cacheRead,
    'cache_creation_input_tokens': cacheCreate,
    'output_tokens': 100,
  },
  'modelUsage': ?modelUsage,
};

Map<String, dynamic>? contextoDe(List<Map<String, dynamic>> events) =>
    events.where((event) => event['type'] == 'contextUsage').firstOrNull;

void main() {
  group('cuánto contexto ocupa la conversación', () {
    test('es el de la ÚLTIMA llamada, no la suma del turno', () {
      // Números de una traza real: cinco pasos de herramienta que reenvían la
      // conversación entera. El contexto verdadero al final eran 58.638
      // tokens; sumar el turno daba 347.037, casi seis veces más, y por eso
      // el anillo saltaba a rojo con el primer pedido.
      final reader = ClaudeStreamReader();
      reader.read({
        'type': 'system',
        'subtype': 'init',
        'session_id': 's1',
        'model': 'claude-sonnet-5',
      });
      reader.read(llamada(input: 2, cacheRead: 0, cacheCreate: 36751));
      reader.read(llamada(input: 2, cacheRead: 36751, cacheCreate: 784));
      reader.read(llamada(input: 2, cacheRead: 48956, cacheCreate: 9680));

      final events = reader.read(
        resultado(
          input: 16,
          cacheRead: 288385,
          cacheCreate: 58636,
          modelUsage: {
            'claude-sonnet-5': {'contextWindow': 1000000},
          },
        ),
      );

      expect(contextoDe(events)!['usedTokens'], 2 + 48956 + 9680);
    });

    test('el contexto de un subagente no cuenta', () {
      // Un subagente tiene su propia conversación: su tamaño no dice nada
      // del contexto de esta.
      final reader = ClaudeStreamReader();
      reader.read({'type': 'system', 'subtype': 'init', 'session_id': 's1'});
      reader.read(llamada(input: 1, cacheRead: 1000, cacheCreate: 0));
      reader.read(
        llamada(
          input: 1,
          cacheRead: 999999,
          cacheCreate: 0,
          parentToolUseId: 'toolu_1',
        ),
      );

      final events = reader.read(
        resultado(
          input: 1,
          cacheRead: 5000,
          cacheCreate: 0,
          modelUsage: {
            'claude-sonnet-5': {'contextWindow': 1000000},
          },
        ),
      );

      expect(contextoDe(events)!['usedTokens'], 1001);
    });

    test('un turno sin llamadas cae al agregado, que es lo único que hay', () {
      final reader = ClaudeStreamReader();
      final events = reader.read(
        resultado(
          input: 10,
          cacheRead: 20,
          cacheCreate: 30,
          modelUsage: {
            'claude-sonnet-5': {'contextWindow': 1000000},
          },
        ),
      );

      expect(contextoDe(events)!['usedTokens'], 60);
    });

    test('el turno siguiente no arrastra el contexto del anterior', () {
      final reader = ClaudeStreamReader();
      reader.read(llamada(input: 1, cacheRead: 500000, cacheCreate: 0));
      reader.read(
        resultado(
          input: 1,
          cacheRead: 1,
          cacheCreate: 0,
          modelUsage: {
            'claude-sonnet-5': {'contextWindow': 1000000},
          },
        ),
      );

      final segundo = reader.read(
        resultado(
          input: 7,
          cacheRead: 3,
          cacheCreate: 0,
          modelUsage: {
            'claude-sonnet-5': {'contextWindow': 1000000},
          },
        ),
      );

      expect(contextoDe(segundo)!['usedTokens'], 10);
    });
  });

  group('cuál es el techo de contexto', () {
    const modelUsage = {
      'claude-haiku-4-5-20251001': {
        'contextWindow': 200000,
        'inputTokens': 900000,
      },
      'claude-sonnet-5': {'contextWindow': 1000000, 'inputTokens': 10},
    };

    test('es la ventana del modelo del turno, no la del que más gastó', () {
      // Un subagente en haiku puede acumular más tokens que el modelo
      // principal. Quedarse con su ventana de 200k satura el anillo con la
      // quinta parte del contexto real.
      final usage = readTurnUsage({
        'modelUsage': modelUsage,
      }, turnModel: 'claude-sonnet-5');

      expect(usage.contextWindowTokens, 1000000);
    });

    test('un alias que no es idéntico igual encuentra su entrada', () {
      final usage = readTurnUsage({
        'modelUsage': modelUsage,
      }, turnModel: 'claude-haiku-4-5');

      expect(usage.contextWindowTokens, 200000);
    });

    test('sin modelo del turno se cae al de más uso, como antes', () {
      final usage = readTurnUsage({'modelUsage': modelUsage});

      expect(usage.contextWindowTokens, 200000);
    });
  });
}
