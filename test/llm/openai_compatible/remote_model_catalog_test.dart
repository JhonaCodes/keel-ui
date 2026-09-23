import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:keel_ui/src/integrations/llm/openai_compatible/remote_model_catalog.dart';
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';

void main() {
  test(
    'OpenRouter carga y conserva modelos que aceptan herramientas',
    () async {
      var requests = 0;
      final catalog = RemoteModelCatalog(
        resolveSecret: (_) async => 'token',
        client: MockClient((request) async {
          requests++;
          expect(request.url.queryParameters['supported_parameters'], 'tools');
          expect(request.headers['authorization'], 'Bearer token');
          return http.Response(
            '{"data":[{"id":"openai/gpt-test","name":"GPT Test"}]}',
            200,
          );
        }),
      );

      expect(await catalog.load(AgentProvider.openRouter), hasLength(1));
      expect(
        (await catalog.load(AgentProvider.openRouter)).single.alias,
        'openai/gpt-test',
      );
      expect(requests, 1);
    },
  );

  test('DeepSeek carga su catálogo remoto', () async {
    final catalog = RemoteModelCatalog(
      resolveSecret: (_) async => 'token',
      client: MockClient((request) async {
        expect(request.url.path, '/models');
        return http.Response('{"data":[{"id":"deepseek-v4-pro"}]}', 200);
      }),
    );

    expect(
      (await catalog.load(AgentProvider.deepSeek)).single.alias,
      'deepseek-v4-pro',
    );
  });

  group('Codex', () {
    late Directory codexHome;

    setUp(() => codexHome = Directory.systemTemp.createTempSync('codex_home'));
    tearDown(() => codexHome.deleteSync(recursive: true));

    test(
      'ofrece los modelos que su propio selector lista, en su orden',
      () async {
        File('${codexHome.path}/models_cache.json').writeAsStringSync(
          jsonEncode({
            'fetched_at': '2026-09-22T22:47:12Z',
            'models': [
              {
                'slug': 'gpt-5.5',
                'display_name': 'GPT-5.5',
                'visibility': 'list',
                'priority': 7,
              },
              {
                'slug': 'gpt-reserve',
                'display_name': 'GPT-Reserve',
                'visibility': 'hide',
                'priority': 3,
              },
              {
                'slug': 'gpt-6-sol',
                'display_name': 'GPT-6-Sol',
                'visibility': 'list',
                'priority': 0,
              },
            ],
          }),
        );
        final catalog = RemoteModelCatalog(codexHome: codexHome.path);

        final options = await catalog.load(AgentProvider.codex);

        expect(options.map((option) => option.alias), [
          kCodexDefaultModelAlias,
          'gpt-6-sol',
          'gpt-5.5',
        ]);
        expect(options[1].label, 'GPT-6-Sol');
      },
    );

    test('sin catálogo local, o con uno roto, usa la lista fija', () async {
      final missing = RemoteModelCatalog(codexHome: codexHome.path);
      expect(await missing.load(AgentProvider.codex), kCodexModelOptions);

      File(
        '${codexHome.path}/models_cache.json',
      ).writeAsStringSync('{"models": [');
      final broken = RemoteModelCatalog(codexHome: codexHome.path);
      expect(await broken.load(AgentProvider.codex), kCodexModelOptions);
    });
  });

  group('Claude', () {
    late Directory home;

    setUp(() => home = Directory.systemTemp.createTempSync('claude_home'));
    tearDown(() => home.deleteSync(recursive: true));

    test('etiqueta cada familia con la versión más nueva que corrió y suma '
        'las opciones extra que el CLI cachea para la cuenta', () async {
      File('${home.path}/.claude.json').writeAsStringSync(
        jsonEncode({
          'projects': {'/tmp/x': <String, dynamic>{}},
          'additionalModelOptionsCache': [
            {
              'value': 'claude-fable-5-1[1m]',
              'label': 'Fable',
              'description':
                  'Fable 5.1 · Most capable for your hardest and '
                  'longest-running tasks',
            },
            {'value': 'opus', 'label': 'Opus'},
            {'label': 'sin value'},
          ],
        }),
      );
      final catalog = RemoteModelCatalog(
        homeDirectory: home.path,
        // Neither first nor last: the ledger is chronological, and the
        // newest version must win wherever it falls.
        observedModels: () async => [
          'claude-opus-5',
          'claude-opus-5-5',
          'claude-opus-4-8',
          'claude-sonnet-5[1m]',
          'opus',
        ],
      );

      final options = await catalog.load(AgentProvider.claude);

      expect(
        {for (final option in options) option.alias: option.label},
        {
          'sonnet': 'Sonnet 5',
          'opus': 'Opus 5.5',
          'fable': 'Fable',
          'haiku': 'Haiku',
          'claude-fable-5-1[1m]': 'Fable 5.1 · 1M',
        },
      );
    });

    test('sin historial ni config del CLI quedan las familias', () async {
      final catalog = RemoteModelCatalog(
        homeDirectory: home.path,
        observedModels: () async => const [],
      );

      expect(await catalog.load(AgentProvider.claude), kClaudeModelOptions);
    });
  });
}
