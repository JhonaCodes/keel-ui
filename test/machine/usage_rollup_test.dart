import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/turn_usage.dart';
import 'package:keel_ui/src/integrations/usage_ledger/usage_ledger.dart';

UsageEntry entry({
  required DateTime at,
  String provider = 'claude',
  String model = 'sonnet',
  String projectId = 'p1',
  int input = 100,
  int output = 20,
  int cacheRead = 0,
  bool tokensReported = true,
}) => UsageEntry(
  id: '$at-$model-$input',
  at: at,
  provider: provider,
  model: model,
  profileId: 'perfil',
  projectId: projectId,
  sessionId: 's1',
  inputTokens: input,
  outputTokens: output,
  cacheReadTokens: cacheRead,
  cacheCreationTokens: 0,
  durationMs: 1000,
  costUsd: 0.01,
  tokensReported: tokensReported,
);

void main() {
  final hoy = DateTime(2026, 8, 23, 15);

  group('por día', () {
    test('devuelve la ventana completa, incluidos los días sin nada', () {
      final days = rollupByDay(
        [entry(at: DateTime(2026, 8, 23, 9))],
        today: hoy,
        days: 5,
      );

      expect(days, hasLength(5));
      expect(days.first.day, DateTime(2026, 8, 19));
      expect(days.last.day, DateTime(2026, 8, 23));
      expect(days.first.total, 0);
      expect(days.last.total, 120);
    });

    test('apila por modelo dentro del mismo día', () {
      final days = rollupByDay(
        [
          entry(at: DateTime(2026, 8, 23, 9)),
          entry(at: DateTime(2026, 8, 23, 11), model: 'opus', input: 500),
          entry(at: DateTime(2026, 8, 23, 12), input: 200),
        ],
        today: hoy,
        days: 2,
      );

      expect(days.last.byModel, {'sonnet': 340, 'opus': 520});
      expect(days.last.total, 860);
    });

    test('lo que cae fuera de la ventana no entra', () {
      final days = rollupByDay(
        [entry(at: DateTime(2026, 7, 1))],
        today: hoy,
        days: 5,
      );

      expect(days.fold(0, (sum, day) => sum + day.total), 0);
    });

    test('un turno sin medición no inventa una barra', () {
      final days = rollupByDay(
        [
          entry(
            at: DateTime(2026, 8, 23),
            provider: 'codex',
            model: '',
            input: 0,
            output: 0,
          ),
        ],
        today: hoy,
        days: 2,
      );

      expect(days.last.byModel, isEmpty);
      expect(days.last.total, 0);
    });
  });

  group('por motor', () {
    test('suma cada uno y ordena por consumo', () {
      final engines = rollupByEngine([
        entry(at: hoy, input: 100),
        entry(at: hoy, input: 300),
        entry(at: hoy, provider: 'codex', model: '', input: 0, output: 0),
      ]);

      expect(engines.first.provider, 'claude');
      expect(engines.first.turns, 2);
      expect(engines.first.inputTokens, 400);
      expect(engines.last.provider, 'codex');
    });

    test('un motor que no informa nada queda marcado, no en cero', () {
      final engines = rollupByEngine([
        entry(at: hoy, provider: 'codex', model: '', input: 0, output: 0),
      ]);

      expect(engines.single.unmeasured, isTrue);
      expect(engines.single.turns, 1);
    });

    test('un motor que informó algo no queda marcado', () {
      final engines = rollupByEngine([entry(at: hoy)]);

      expect(engines.single.unmeasured, isFalse);
    });

    test('los turnos sin medición se cuentan aparte del total', () {
      // Un turno parado o caído gastó y no informó nada. Sumado en silencio
      // baja el promedio por turno sin explicar por qué; contado aparte, se
      // puede leer "3 turnos, 2 sin medición".
      final engines = rollupByEngine([
        entry(at: hoy, input: 100),
        entry(at: hoy, input: 0, output: 0, tokensReported: false),
        entry(at: hoy, input: 0, output: 0, tokensReported: false),
      ]);

      expect(engines.single.turns, 3);
      expect(engines.single.unmeasuredTurns, 2);
      // El motor SÍ informó en un turno, así que no está ciego del todo.
      expect(engines.single.unmeasured, isFalse);
    });

    test('sin turnos sin medición el contador queda en cero', () {
      final engines = rollupByEngine([entry(at: hoy)]);

      expect(engines.single.unmeasuredTurns, 0);
    });
  });

  test('por proyecto ordena de mayor a menor', () {
    final totals = rollupByProject([
      entry(at: hoy, projectId: 'a', input: 100),
      entry(at: hoy, projectId: 'b', input: 900),
      entry(at: hoy, projectId: 'a', input: 100),
    ]);

    expect(totals.keys.toList(), ['b', 'a']);
    expect(totals['a'], 240);
  });

  test('los modelos salen en orden de consumo, para la leyenda', () {
    final days = rollupByDay(
      [
        entry(at: hoy, model: 'haiku', input: 10),
        entry(at: hoy, model: 'opus', input: 900),
        entry(at: hoy, input: 400),
      ],
      today: hoy,
      days: 2,
    );

    expect(modelsIn(days), ['opus', 'sonnet', 'haiku']);
  });

  group('leer el evento del CLI', () {
    test('saca los contadores y el modelo que condujo el turno', () {
      final usage = readTurnUsage({
        'is_error': false,
        'total_cost_usd': 0.42,
        'duration_ms': 8100,
        'usage': {
          'input_tokens': 120,
          'output_tokens': 340,
          'cache_read_input_tokens': 9000,
          'cache_creation_input_tokens': 500,
        },
        'modelUsage': {
          'claude-haiku-4-5': {
            'inputTokens': 30,
            'cacheReadInputTokens': 0,
            'cacheCreationInputTokens': 0,
            'contextWindow': 200000,
          },
          'claude-sonnet-5': {
            'inputTokens': 120,
            'cacheReadInputTokens': 9000,
            'cacheCreationInputTokens': 500,
            'contextWindow': 1000000,
          },
        },
      });

      expect(usage.model, 'claude-sonnet-5');
      expect(usage.costUsd, 0.42);
      expect(usage.durationMs, 8100);
      expect(usage.inputTokens, 120);
      expect(usage.outputTokens, 340);
      expect(usage.cacheReadTokens, 9000);
      expect(usage.contextWindowTokens, 1000000);
    });

    test('el contexto ocupado es entrada más caché, sin la salida', () {
      final usage = readTurnUsage({
        'usage': {
          'input_tokens': 100,
          'output_tokens': 999,
          'cache_read_input_tokens': 50,
          'cache_creation_input_tokens': 25,
        },
      });

      expect(usedContextOf(usage), 175);
    });

    test('un result sin usage no rompe: devuelve ceros', () {
      final usage = readTurnUsage({'is_error': true});

      expect(usage.model, isEmpty);
      expect(usage.inputTokens, 0);
      expect(usage.contextWindowTokens, 0);
    });
  });
}
