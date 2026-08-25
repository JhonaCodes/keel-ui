import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/claude_stream_events.dart';

Map<String, dynamic> _assistant(
  List<Map<String, dynamic>> content, {
  String? parent,
}) => {
  'type': 'assistant',
  'parent_tool_use_id': ?parent,
  'message': {'content': content},
};

Map<String, dynamic> _toolResult(
  String id,
  Object? content, {
  bool isError = false,
}) => {
  'type': 'user',
  'message': {
    'content': [
      {
        'type': 'tool_result',
        'tool_use_id': id,
        'content': content,
        'is_error': isError,
      },
    ],
  },
};

void main() {
  group('lo del padre y lo del hijo no se mezclan', () {
    test('un Task abre un subagente con su pedido, no con una etiqueta', () {
      final reader = ClaudeStreamReader();
      final events = reader.read(
        _assistant([
          {
            'type': 'tool_use',
            'id': 'toolu_01',
            'name': 'Task',
            'input': {
              'subagent_type': 'Explore',
              'description': 'Buscar el precio final',
              'prompt': 'Encontrá dónde se resuelve el precio final del lote.',
            },
          },
        ]),
      );

      final started = events.firstWhere((e) => e['type'] == 'subagentStarted');
      expect(started['id'], 'toolu_01');
      expect(started['agentType'], 'Explore');
      expect(started['ask'], 'Buscar el precio final');
      expect(started['prompt'], contains('precio final del lote'));

      // El `toolUse` sigue saliendo: el padre pasa a «trabajando» por él.
      expect(events.any((e) => e['type'] == 'toolUse'), isTrue);
    });

    test('sin description, el pedido es la primera frase del prompt', () {
      final reader = ClaudeStreamReader();
      final events = reader.read(
        _assistant([
          {
            'type': 'tool_use',
            'id': 'toolu_02',
            'name': 'Task',
            'input': {
              'subagent_type': 'Plan',
              'prompt':
                  'Armá un plan para el bid. No toques los goldens todavía.',
            },
          },
        ]),
      );

      expect(
        events.firstWhere((e) => e['type'] == 'subagentStarted')['ask'],
        'Armá un plan para el bid.',
      );
    });

    test('el pensamiento del subagente sale marcado, no como del padre', () {
      final reader = ClaudeStreamReader();
      final events = reader.read(
        _assistant(parent: 'toolu_01', [
          {'type': 'thinking', 'thinking': 'Hay dos rutas posibles.'},
          {'type': 'text', 'text': 'Está en lot_repository.dart:88.'},
        ]),
      );

      expect(events, [
        {
          'type': 'subagentReasoning',
          'id': 'toolu_01',
          'text': 'Hay dos rutas posibles.',
        },
        {
          'type': 'subagentText',
          'id': 'toolu_01',
          'text': 'Está en lot_repository.dart:88.',
        },
      ]);
      // Lo que rompía antes: esto salía como `reasoningChunk` y entraba al
      // buffer del padre, firmado por alguien que no lo pensó.
      expect(events.any((e) => e['type'] == 'reasoningChunk'), isFalse);
      expect(events.any((e) => e['type'] == 'assistantText'), isFalse);
    });

    test('las herramientas del subagente son suyas', () {
      final reader = ClaudeStreamReader();
      final events = reader.read(
        _assistant(parent: 'toolu_01', [
          {
            'type': 'tool_use',
            'id': 'toolu_09',
            'name': 'Grep',
            'input': {'pattern': 'finalPrice'},
          },
        ]),
      );

      expect(events.single, {
        'type': 'subagentToolUse',
        'id': 'toolu_01',
        'name': 'Grep',
        'input': {'pattern': 'finalPrice'},
      });
    });
  });

  group('la devolución', () {
    test('el tool_result del Task cierra el subagente', () {
      final reader = ClaudeStreamReader();
      reader.read(
        _assistant([
          {
            'type': 'tool_use',
            'id': 'toolu_01',
            'name': 'Task',
            'input': {'subagent_type': 'Explore', 'prompt': 'buscá'},
          },
        ]),
      );

      final events = reader.read(
        _toolResult('toolu_01', 'Está en la línea 88'),
      );
      expect(events.single, {
        'type': 'subagentFinished',
        'id': 'toolu_01',
        'result': 'Está en la línea 88',
        'isError': false,
      });
    });

    test('un tool_result de una herramienta común no emite nada', () {
      final reader = ClaudeStreamReader();
      expect(reader.read(_toolResult('toolu_77', 'ok')), isEmpty);
    });

    test('un Task que falló se cierra como fallado', () {
      final reader = ClaudeStreamReader();
      reader.read(
        _assistant([
          {
            'type': 'tool_use',
            'id': 'toolu_03',
            'name': 'Task',
            'input': {'subagent_type': 'Explore', 'prompt': 'buscá'},
          },
        ]),
      );

      expect(
        reader
            .read(_toolResult('toolu_03', 'sin resultados', isError: true))
            .single['isError'],
        isTrue,
      );
    });

    test('cerrado una vez, cerrado para siempre', () {
      final reader = ClaudeStreamReader();
      reader.read(
        _assistant([
          {
            'type': 'tool_use',
            'id': 'toolu_04',
            'name': 'Task',
            'input': {'subagent_type': 'Explore', 'prompt': 'buscá'},
          },
        ]),
      );
      reader.read(_toolResult('toolu_04', 'listo'));
      expect(reader.read(_toolResult('toolu_04', 'listo')), isEmpty);
    });
  });

  group('lo que ya funcionaba sigue funcionando', () {
    test('el turno del padre se lee igual que antes', () {
      final reader = ClaudeStreamReader();
      final events = reader.read(
        _assistant([
          {'type': 'thinking', 'thinking': 'A ver.'},
          {'type': 'text', 'text': 'Listo.'},
        ]),
      );

      expect(events, [
        {'type': 'reasoningChunk', 'text': 'A ver.'},
        {'type': 'assistantText', 'text': 'Listo.'},
      ]);
    });

    test('un comando de control puede devolver content como texto', () {
      final reader = ClaudeStreamReader();

      final events = reader.read({
        'type': 'assistant',
        'message': {'content': 'Conversation compacted.'},
      });

      expect(events, [
        {'type': 'assistantText', 'text': 'Conversation compacted.'},
      ]);
    });

    test('el texto directo de un subagente conserva su autoría', () {
      final reader = ClaudeStreamReader();

      final events = reader.read({
        'type': 'assistant',
        'parent_tool_use_id': 'toolu_compact',
        'message': {'content': 'Context compacted.'},
      });

      expect(events, [
        {
          'type': 'subagentText',
          'id': 'toolu_compact',
          'text': 'Context compacted.',
        },
      ]);
    });

    test('un evento user con content textual no derriba el lector', () {
      final reader = ClaudeStreamReader();

      expect(
        reader.read({
          'type': 'user',
          'message': {'content': 'Compaction boundary.'},
        }),
        isEmpty,
      );
    });

    test('el bloqueo de un hook se reconoce por su marca', () {
      final reader = ClaudeStreamReader();
      final events = reader.read(
        _toolResult(
          'toolu_50',
          'PreToolUse:Bash blocked\n[keel:hook sin-push]',
        ),
      );

      expect(events.single['type'], 'permissionDenied');
      expect(events.single['toolName'], 'Bash');
    });

    test('el init trae el id de sesión', () {
      final reader = ClaudeStreamReader();
      expect(
        reader.read({
          'type': 'system',
          'subtype': 'init',
          'session_id': 'abc-123',
        }).single,
        {'type': 'sessionStarted', 'sessionId': 'abc-123'},
      );
    });

    test('el result trae los contadores del turno', () {
      final reader = ClaudeStreamReader();
      final events = reader.read({
        'type': 'result',
        'is_error': false,
        'total_cost_usd': 0.42,
        'duration_ms': 1200,
        'usage': {
          'input_tokens': 10,
          'output_tokens': 20,
          'cache_read_input_tokens': 30,
          'cache_creation_input_tokens': 5,
        },
        'modelUsage': {
          'claude-opus-5': {'inputTokens': 10, 'contextWindow': 200000},
        },
      });

      final turn = events.first;
      expect(turn['type'], 'turnCompleted');
      expect(turn['costUsd'], 0.42);
      expect(turn['durationMs'], 1200);
      expect(turn['outputTokens'], 20);
      expect(turn['model'], 'claude-opus-5');
      expect(events.last, {
        'type': 'contextUsage',
        'usedTokens': 45,
        'contextWindowTokens': 200000,
      });
    });
  });

  group('la primera frase', () {
    test('corta en el punto', () {
      expect(firstSentenceOf('Uno. Dos. Tres.'), 'Uno.');
    });

    test('aplana los saltos de línea', () {
      expect(firstSentenceOf('Uno\n  y medio. Dos.'), 'Uno y medio.');
    });

    test('sin puntuación devuelve todo', () {
      expect(firstSentenceOf('Sin puntuación'), 'Sin puntuación');
    });

    test('recorta lo muy largo sin cortar una palabra al medio', () {
      final resumen = firstSentenceOf('palabra ' * 40);
      expect(resumen.length, lessThanOrEqualTo(121));
      expect(resumen, endsWith('…'));
      expect(resumen, isNot(contains('palabr…')));
    });

    test('un texto vacío no inventa nada', () {
      expect(firstSentenceOf('   \n  '), '');
    });
  });
}
