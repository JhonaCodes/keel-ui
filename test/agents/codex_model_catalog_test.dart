import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_core/core/services/user_shell_path.dart';
import 'package:keel_core/integrations/llm/openai_compatible/remote_model_catalog.dart';
import 'package:keel_core/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/model_catalog_viewmodel.dart';

void main() {
  test(
    'codex models come from `codex debug models` of the binary Keel runs',
    () async {
      // test/run_agent_codex_chat.sh puts a fake codex first on the PATH.
      final fakeCodex = File('test/agents/fixtures/codex_cli/codex').absolute;
      expect(await UserShellPath.locate('codex'), fakeCodex.path);
      // An empty CODEX_HOME: no cache file another codex could have written.
      final codexHome = Directory.systemTemp.createTempSync('keel-codex-home-');
      addTearDown(() => codexHome.deleteSync(recursive: true));

      final options = await RemoteModelCatalog(
        codexHome: codexHome.path,
      ).load(AgentProvider.codex);

      // The config's own model first, then what the CLI lists, in its order.
      expect(options.map((option) => option.alias), [
        '',
        'gpt-live-b',
        'gpt-live-a',
      ]);
      final liveA = options.firstWhere((option) => option.alias == 'gpt-live-a');
      expect(liveA.efforts, ['low', 'medium', 'high']);
      expect(liveA.defaultEffort, 'medium');
    },
    skip: Platform.environment['KEEL_FAKE_CODEX_CHAT'] != '1',
  );

  test(
    'the effort sent to codex is one the model accepts',
    () async {
      final catalog = ModelCatalogService.instance.notifier;

      // gpt-live-a: low/medium/high, default medium. `max` would be rejected
      // by the API: it falls back to the model's default.
      expect(
        await catalog.effortFor(AgentProvider.codex, 'gpt-live-a', 'max'),
        'medium',
      );
      expect(
        await catalog.effortFor(AgentProvider.codex, 'gpt-live-b', 'ultra'),
        'ultra',
      );
      // No model chosen: codex's config decides, so a level goes only when
      // every listed model takes it.
      expect(await catalog.effortFor(AgentProvider.codex, '', 'high'), 'high');
      expect(await catalog.effortFor(AgentProvider.codex, '', 'low'), '');
    },
    skip: Platform.environment['KEEL_FAKE_CODEX_CHAT'] != '1',
  );
}
