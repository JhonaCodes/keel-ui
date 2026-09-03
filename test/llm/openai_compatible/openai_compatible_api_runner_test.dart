import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/integrations/llm/llm.dart';
import 'package:keel_ui/src/integrations/llm/openai_compatible/openai_compatible_api_runner.dart';
import 'package:keel_ui/src/integrations/llm/openai_compatible/openai_tool_bridge.dart';

const _spec = LlmTurnSpec(
  prompt: 'hola',
  workingDirectory: '.',
  model: 'openai/gpt-4',
  fullFileSystemAccess: false,
  effort: 'medium',
  additionalSystemPrompt: 'Respondé breve.',
);

void main() {
  group('OpenAiCompatibleApiRunner', () {
    test('la red contra bucles vive alta, no como presupuesto de trabajo', () {
      final runner = OpenAiCompatibleApiRunner(
        baseUrl: 'https://api.deepseek.com',
        secretRef: 'DEEPSEEK_API_KEY',
        resolveSecret: (_) async => 'test-token-deepseek',
      );

      // A los proveedores por CLI nadie les corta el ciclo. Un tope bajo acá
      // no ahorraba: cortaba el nodo a media tarea y obligaba a relanzarlo.
      expect(runner.maxToolRounds, kDefaultOpenAiCompatibleMaxToolRounds);
      expect(runner.maxToolRounds, greaterThanOrEqualTo(200));
    });

    test('sin límite declarado el techo es el tope, nunca cero', () {
      // La mitad que importa del `Math.min(...) || outputTokenMax` de opencode:
      // un modelo que no declara su salida daría 0, y un 0 deja el request sin
      // límite útil — que es el 402 de vuelta.
      expect(
        openAiCompatibleMaxOutputTokens(),
        kOpenAiCompatibleOutputTokenMax,
      );
      expect(
        openAiCompatibleMaxOutputTokens(modelOutputLimit: 0),
        kOpenAiCompatibleOutputTokenMax,
      );
      expect(
        openAiCompatibleMaxOutputTokens(modelOutputLimit: null),
        kOpenAiCompatibleOutputTokenMax,
      );

      // Holgado contra un turno real, y muy por debajo del techo de un modelo
      // de 128k: si lo alcanzara, el crédito exigido volvería a ser el máximo
      // teórico del modelo.
      expect(kOpenAiCompatibleOutputTokenMax, greaterThanOrEqualTo(32000));
      expect(kOpenAiCompatibleOutputTokenMax, lessThan(131072));
    });

    test('gana el menor entre el límite del modelo y el tope', () {
      // Un modelo más chico que el tope manda: pedir más de lo que puede emitir
      // encarece la reserva sin comprar nada.
      expect(openAiCompatibleMaxOutputTokens(modelOutputLimit: 8192), 8192);

      // Un modelo más grande no levanta el tope: ese es el punto del recorte.
      expect(
        openAiCompatibleMaxOutputTokens(modelOutputLimit: 131072),
        kOpenAiCompatibleOutputTokenMax,
      );

      // Y el tope es parametrizable, como el `outputTokenMax` de opencode.
      expect(
        openAiCompatibleMaxOutputTokens(
          modelOutputLimit: 131072,
          outputTokenMax: 16000,
        ),
        16000,
      );
    });

    test('el default corta una cadena de tools infinita, y no antes', () async {
      var requests = 0;
      final runner = OpenAiCompatibleApiRunner(
        baseUrl: 'https://api.deepseek.com',
        secretRef: 'DEEPSEEK_API_KEY',
        resolveSecret: (_) async => 'test-token-deepseek',
        toolBridge: _FakeToolBridge(),
        client: MockClient((request) async {
          requests++;
          return http.Response(
            [
              'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_$requests","type":"function","function":{"name":"Read","arguments":"{\\"path\\":\\"file-$requests.md\\"}"}}]},"finish_reason":"tool_calls"}]}',
              'data: [DONE]',
              '',
            ].join('\n'),
            200,
          );
        }),
      );

      final events = await runner
          .run(_spec, userPath: '', cancel: const Stream<void>.empty())
          .toList();

      // El modelo pide tool para siempre: la red tiene que frenarlo. Se ata al
      // valor de la constante, no a un número escrito a mano — así subir el
      // tope no obliga a editar el test, pero seguir teniendo red sí se prueba.
      expect(requests, kDefaultOpenAiCompatibleMaxToolRounds + 1);
      // Y frena SIN romper el turno: el trabajo hecho se entrega.
      expect(events.where((event) => event['type'] == 'failure'), isEmpty);
      expect(events.last, containsPair('isError', false));
    });

    test('entrega el historial aislado antes del mensaje actual', () async {
      late http.Request seen;
      final runner = OpenAiCompatibleApiRunner(
        baseUrl: 'https://openrouter.ai/api/v1',
        secretRef: 'OPENROUTER_API_KEY',
        resolveSecret: (_) async => 'test-token-openrouter',
        client: MockClient((request) async {
          seen = request;
          return http.Response('data: [DONE]\n', 200);
        }),
      );

      await runner
          .run(
            const LlmTurnSpec(
              prompt: 'Sí, aplicalo.',
              workingDirectory: '.',
              model: 'openai/gpt-4',
              fullFileSystemAccess: false,
              effort: 'medium',
              conversationHistory: [
                LlmConversationMessage(
                  role: LlmConversationRole.user,
                  content: '¿Podés aplicar la migración?',
                ),
                LlmConversationMessage(
                  role: LlmConversationRole.assistant,
                  content: 'Encontré tres archivos. ¿La aplico?',
                ),
              ],
            ),
            userPath: '',
            cancel: const Stream<void>.empty(),
          )
          .drain<void>();

      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['messages'], [
        {'role': 'user', 'content': '¿Podés aplicar la migración?'},
        {'role': 'assistant', 'content': 'Encontré tres archivos. ¿La aplico?'},
        {'role': 'user', 'content': 'Sí, aplicalo.'},
      ]);
    });

    test('OpenRouter conserva provider/model y normaliza el stream', () async {
      late http.Request seen;
      final runner = OpenAiCompatibleApiRunner(
        baseUrl: 'https://openrouter.ai/api/v1',
        secretRef: 'OPENROUTER_API_KEY',
        resolveSecret: (_) async => 'test-token-openrouter',
        client: MockClient((request) async {
          seen = request;
          return http.Response(
            [
              'data: {"id":"chatcmpl-1","choices":[{"delta":{"content":"Ho"}}]}',
              'data: {"choices":[{"delta":{"content":"la"}}]}',
              'data: {"choices":[{"finish_reason":"stop","delta":{}}],"usage":{"prompt_tokens":100,"completion_tokens":20,"total_tokens":120,"cost":0.125,"prompt_tokens_details":{"cached_tokens":60,"cache_write_tokens":10}}}',
              'data: [DONE]',
              '',
            ].join('\n'),
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        }),
      );

      final events = await runner
          .run(_spec, userPath: '', cancel: const Stream<void>.empty())
          .toList();

      expect(seen.method, 'POST');
      expect(
        seen.url.toString(),
        'https://openrouter.ai/api/v1/chat/completions',
      );
      expect(seen.headers['authorization'], 'Bearer test-token-openrouter');
      expect(seen.headers['content-type'], contains('application/json'));

      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['model'], 'openai/gpt-4');
      expect(body['stream'], isTrue);
      expect(body['stream_options'], {'include_usage': true});
      expect(
        body['max_tokens'],
        openAiCompatibleMaxOutputTokens(),
        reason:
            'sin max_tokens el proveedor reserva el techo del modelo y cobra '
            'esa reserva por adelantado: la cuenta recibe 402 en todo request',
      );
      expect(body['messages'], [
        {'role': 'system', 'content': 'Respondé breve.'},
        {'role': 'user', 'content': 'hola'},
      ]);
      expect(events, [
        {'type': 'assistantText', 'text': 'Ho'},
        {'type': 'assistantText', 'text': 'la'},
        {
          'type': 'turnCompleted',
          'isError': false,
          'costUsd': 0.125,
          'costReported': true,
          'durationMs': isA<int>(),
          'model': 'openai/gpt-4',
          'inputTokens': 30,
          'outputTokens': 20,
          'cacheReadTokens': 60,
          'cacheCreationTokens': 10,
          'tokensReported': true,
          'usageIsCumulative': false,
          'contextUsedTokens': 100,
          'contextWindowTokens': 0,
        },
      ]);
    });

    test('DeepSeek conserva el nombre plano del modelo', () async {
      late http.Request seen;
      final runner = OpenAiCompatibleApiRunner(
        baseUrl: 'https://api.deepseek.com',
        secretRef: 'DEEPSEEK_API_KEY',
        resolveSecret: (_) async => 'test-token-deepseek',
        client: MockClient((request) async {
          seen = request;
          return http.Response('data: [DONE]\n', 200);
        }),
      );

      final events = await runner
          .run(
            const LlmTurnSpec(
              prompt: 'hola',
              workingDirectory: '.',
              model: 'deepseek-chat',
              fullFileSystemAccess: false,
              effort: 'medium',
            ),
            userPath: '',
            cancel: const Stream<void>.empty(),
          )
          .toList();

      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(seen.url.toString(), 'https://api.deepseek.com/chat/completions');
      expect(body['model'], 'deepseek-chat');
      expect(events.single['type'], 'turnCompleted');
      expect(events.single['isError'], isFalse);
    });

    test('ejecuta tool calls autorizadas y conserva reasoning de DeepSeek', () async {
      final requests = <http.Request>[];
      final bridge = _FakeToolBridge();
      final runner = OpenAiCompatibleApiRunner(
        baseUrl: 'https://api.deepseek.com',
        secretRef: 'DEEPSEEK_API_KEY',
        resolveSecret: (_) async => 'test-token-deepseek',
        toolBridge: bridge,
        client: MockClient((request) async {
          requests.add(request);
          if (requests.length == 1) {
            return http.Response(
              [
                'data: {"choices":[{"delta":{"reasoning_content":"Necesito leer."}}]}',
                'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","type":"function","function":{"name":"Read","arguments":"{\\"path\\":"}}]}}]}',
                'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"\\"README.md\\"}"}}]},"finish_reason":"tool_calls"}]}',
                'data: [DONE]',
                '',
              ].join('\n'),
              200,
            );
          }
          return http.Response(
            [
              'data: {"choices":[{"delta":{"content":"Contenido leido."}}],"usage":{"prompt_tokens":8,"completion_tokens":3}}',
              'data: [DONE]',
              '',
            ].join('\n'),
            200,
          );
        }),
      );

      final events = await runner
          .run(
            const LlmTurnSpec(
              prompt: 'leé el readme',
              workingDirectory: '.',
              model: 'deepseek-reasoner',
              fullFileSystemAccess: false,
              effort: 'medium',
            ),
            userPath: '',
            cancel: const Stream<void>.empty(),
          )
          .toList();

      expect(requests, hasLength(2));
      expect(bridge.executions, hasLength(1));
      expect(bridge.executions.single.$1, 'Read');
      expect(bridge.executions.single.$2, {'path': 'README.md'});
      final secondBody = jsonDecode(requests.last.body) as Map<String, dynamic>;
      final messages = secondBody['messages'] as List;
      expect(messages[1], {
        'role': 'assistant',
        'content': null,
        'reasoning_content': 'Necesito leer.',
        'tool_calls': [
          {
            'id': 'call_1',
            'type': 'function',
            'function': {'name': 'Read', 'arguments': '{"path":"README.md"}'},
          },
        ],
      });
      expect(messages[2], {
        'role': 'tool',
        'tool_call_id': 'call_1',
        'content': 'contenido-del-readme',
      });
      expect(events.where((event) => event['type'] == 'toolUse').single, {
        'type': 'toolUse',
        'name': 'Read',
        'input': {'path': 'README.md'},
      });
      expect(events.where((event) => event['type'] == 'assistantText').single, {
        'type': 'assistantText',
        'text': 'Contenido leido.',
      });
      expect(bridge.closed, isTrue);
    });

    test('corta un reintento estéril antes de agotar todas las rondas', () async {
      final requests = <http.Request>[];
      final bridge = _FakeToolBridge();
      final runner = OpenAiCompatibleApiRunner(
        baseUrl: 'https://api.deepseek.com',
        secretRef: 'DEEPSEEK_API_KEY',
        resolveSecret: (_) async => 'test-token-deepseek',
        toolBridge: bridge,
        maxToolRounds: 8,
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            [
              'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_${requests.length}","type":"function","function":{"name":"Read","arguments":"{\\"path\\":\\"README.md\\"}"}}]},"finish_reason":"tool_calls"}]}',
              'data: [DONE]',
              '',
            ].join('\n'),
            200,
          );
        }),
      );

      final events = await runner
          .run(
            const LlmTurnSpec(
              prompt: 'leé una vez',
              workingDirectory: '.',
              model: 'deepseek-chat',
              fullFileSystemAccess: false,
              effort: 'medium',
            ),
            userPath: '',
            cancel: const Stream<void>.empty(),
          )
          .toList();

      expect(bridge.executions, hasLength(1));
      expect(requests.length, lessThan(9));
      expect(
        events.where((event) => event['type'] == 'failure').single['message'],
        contains('reintento estéril'),
      );
    });

    test(
      'un límite interno informa que la causa concreta ya fue mostrada',
      () async {
        var requests = 0;
        final runner = OpenAiCompatibleApiRunner(
          baseUrl: 'https://openrouter.ai/api/v1',
          secretRef: 'OPENROUTER_API_KEY',
          resolveSecret: (_) async => 'test-token-openrouter',
          toolBridge: _FakeToolBridge(),
          maxToolRounds: 1,
          client: MockClient((request) async {
            requests++;
            return http.Response(
              [
                'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_$requests","type":"function","function":{"name":"Read","arguments":"{\\"path\\":\\"file-$requests.md\\"}"}}]},"finish_reason":"tool_calls"}]}',
                'data: [DONE]',
                '',
              ].join('\n'),
              200,
            );
          }),
        );

        final events = await runner
            .run(_spec, userPath: '', cancel: const Stream<void>.empty())
            .toList();

        // Agotar la red NO es un fallo del turno: marcarlo como error tiraba
        // todo el trabajo del nodo y obligaba a pagarlo dos veces. Se cierra
        // bien, con el aviso en el texto para que el siguiente lo continúe.
        expect(events.where((event) => event['type'] == 'failure'), isEmpty);
        expect(events.last, containsPair('isError', false));
        expect(
          events
              .where((event) => event['type'] == 'assistantText')
              .last['text'],
          allOf(contains('Corté el ciclo'), contains('no lo repitas')),
        );
      },
    );

    test('un 429 se reintenta en vez de matar el nodo', () async {
      var requests = 0;
      final runner = OpenAiCompatibleApiRunner(
        baseUrl: 'https://openrouter.ai/api/v1',
        secretRef: 'OPENROUTER_API_KEY',
        resolveSecret: (_) async => 'test-token-openrouter',
        client: MockClient((request) async {
          requests++;
          // Los dos primeros intentos rebotan por cuota; el tercero pasa.
          if (requests < 3) {
            return http.Response('{"error":"rate limited"}', 429, headers: {
              'retry-after': '1',
            });
          }
          return http.Response(
            [
              'data: {"choices":[{"delta":{"content":"listo"}}]}',
              'data: [DONE]',
              '',
            ].join('\n'),
            200,
          );
        }),
      );

      final events = await runner
          .run(_spec, userPath: '', cancel: const Stream<void>.empty())
          .toList();

      expect(requests, 3);
      expect(events.where((event) => event['type'] == 'failure'), isEmpty);
      expect(events.last, containsPair('isError', false));
    });

    test('un 4xx que no es de cuota no se reintenta', () async {
      var requests = 0;
      final runner = OpenAiCompatibleApiRunner(
        baseUrl: 'https://openrouter.ai/api/v1',
        secretRef: 'OPENROUTER_API_KEY',
        resolveSecret: (_) async => 'test-token-openrouter',
        client: MockClient((request) async {
          requests++;
          return http.Response('{"error":"bad request"}', 400);
        }),
      );

      final events = await runner
          .run(_spec, userPath: '', cancel: const Stream<void>.empty())
          .toList();

      // Reintentar un pedido mal formado es quemar plata en el mismo error.
      expect(requests, 1);
      expect(
        events.where((event) => event['type'] == 'failure').single['message'],
        startsWith('400'),
      );
    });

    test('MiniMax conserva el nombre plano y la base /v1', () async {
      late http.Request seen;
      final runner = OpenAiCompatibleApiRunner(
        baseUrl: 'https://api.minimax.io/v1',
        secretRef: 'MINIMAX_API_KEY',
        resolveSecret: (_) async => 'test-token-minimax',
        client: MockClient((request) async {
          seen = request;
          return http.Response('data: [DONE]\n', 200);
        }),
      );

      await runner
          .run(
            const LlmTurnSpec(
              prompt: 'hola',
              workingDirectory: '.',
              model: 'MiniMax-M1',
              fullFileSystemAccess: false,
              effort: 'medium',
            ),
            userPath: '',
            cancel: const Stream<void>.empty(),
          )
          .drain<void>();

      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(seen.url.toString(), 'https://api.minimax.io/v1/chat/completions');
      expect(body['model'], 'MiniMax-M1');
    });

    test('un secret pendiente corta antes de salir a la red', () async {
      var called = false;
      final runner = OpenAiCompatibleApiRunner(
        baseUrl: 'https://openrouter.ai/api/v1',
        secretRef: 'OPENROUTER_API_KEY',
        resolveSecret: (_) async => null,
        client: MockClient((request) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );

      final events = await runner
          .run(_spec, userPath: '', cancel: const Stream<void>.empty())
          .toList();

      expect(called, isFalse);
      expect(events, [
        {
          'type': 'failure',
          'message': 'Falta configurar el secret OPENROUTER_API_KEY.',
        },
        {
          'type': 'turnCompleted',
          'isError': true,
          'hasReportedFailure': true,
          'costUsd': 0.0,
          'durationMs': isA<int>(),
          'model': 'openai/gpt-4',
          'inputTokens': 0,
          'outputTokens': 0,
          'cacheReadTokens': 0,
          'cacheCreationTokens': 0,
        },
      ]);
    });

    test('la API key inyectada evita consultar storage en el runner', () async {
      var resolverCalled = false;
      late http.Request seen;
      final runner = OpenAiCompatibleApiRunner(
        baseUrl: 'https://openrouter.ai/api/v1',
        secretRef: 'OPENROUTER_API_KEY',
        apiKey: 'key-del-engine-principal',
        resolveSecret: (_) async {
          resolverCalled = true;
          return null;
        },
        client: MockClient((request) async {
          seen = request;
          return http.Response('data: [DONE]\n', 200);
        }),
      );

      await runner
          .run(_spec, userPath: '', cancel: const Stream<void>.empty())
          .drain<void>();

      expect(resolverCalled, isFalse);
      expect(seen.headers['authorization'], 'Bearer key-del-engine-principal');
    });

    test(
      'sin API key falla de forma controlada sin consultar storage',
      () async {
        var called = false;
        final runner = OpenAiCompatibleApiRunner(
          baseUrl: 'https://api.deepseek.com',
          secretRef: 'DEEPSEEK_API_KEY',
          client: MockClient((request) async {
            called = true;
            return http.Response('{}', 200);
          }),
        );

        final events = await runner
            .run(_spec, userPath: '', cancel: const Stream<void>.empty())
            .toList();

        expect(called, isFalse);
        expect(events.first, {
          'type': 'failure',
          'message': 'Falta configurar el secret DEEPSEEK_API_KEY.',
        });
      },
    );

    test('cancelar antes de resolver el secret no sale a la red', () async {
      var called = false;
      final resolverStarted = Completer<void>();
      final secretCompleter = Completer<String>();
      final cancelController = StreamController<void>();
      final runner = OpenAiCompatibleApiRunner(
        baseUrl: 'https://openrouter.ai/api/v1',
        secretRef: 'OPENROUTER_API_KEY',
        resolveSecret: (_) {
          resolverStarted.complete();
          return secretCompleter.future;
        },
        client: MockClient((request) async {
          called = true;
          return http.Response('data: [DONE]\n', 200);
        }),
      );

      final eventsFuture = runner
          .run(_spec, userPath: '', cancel: cancelController.stream)
          .toList();

      await resolverStarted.future;
      cancelController.add(null);
      await cancelController.close();
      secretCompleter.complete('test-token-openrouter');

      final events = await eventsFuture;

      expect(called, isFalse);
      expect(events, isEmpty);
    });

    test(
      'resolver un secret sin storage no intenta inicializar LocalDB',
      () async {
        LocalDatabase.markUnavailable();

        expect(await resolveLlmSecret('OPENROUTER_API_KEY'), isNull);
      },
    );
  });
}

class _FakeToolBridge implements OpenAiToolBridge {
  final List<(String, Map<String, dynamic>)> executions = [];
  bool closed = false;

  @override
  Future<List<OpenAiFunctionDefinition>> functions(LlmTurnSpec spec) async => [
    const OpenAiFunctionDefinition(
      name: 'Read',
      description: 'Read a file.',
      parameters: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string'},
        },
        'required': ['path'],
      },
    ),
  ];

  @override
  Future<OpenAiToolResult> execute(
    LlmTurnSpec spec,
    String name,
    Map<String, dynamic> arguments,
  ) async {
    executions.add((name, arguments));
    return const OpenAiToolResult(content: 'contenido-del-readme');
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}
