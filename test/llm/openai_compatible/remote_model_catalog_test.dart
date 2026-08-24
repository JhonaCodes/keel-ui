import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:keel_ui/src/integrations/llm/openai_compatible/remote_model_catalog.dart';
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
}
