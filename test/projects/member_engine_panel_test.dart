import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/integrations/llm/openai_compatible/remote_model_catalog.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/member_engine_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalDatabase.markUnavailable();

  testWidgets('OpenRouter normaliza modelo, carga catálogo y enlaza Secrets', (
    tester,
  ) async {
    final catalog = RemoteModelCatalog(
      resolveSecret: (_) async => 'token',
      client: MockClient(
        (_) async => http.Response(
          '{"data":[{"id":"openai/gpt-test","name":"GPT Test","supported_parameters":["tools"]}]}',
          200,
        ),
      ),
    );
    final epoch = DateTime(2026);
    final project = Project(
      id: 'p',
      name: 'nui-app',
      purpose: '',
      workingDirectory: '/tmp/nui',
      createdAt: epoch,
    );
    final member = AgentProfile(
      id: 'agent',
      name: 'resolver',
      role: 'resolver',
      systemPrompt: '',
      model: 'sonnet',
      effort: 'medium',
      createdAt: epoch,
    );

    await tester.pumpWidget(
      MaterialApp(
        // The widgets under test read AppLocalizations; without the
        // delegates `AppLocalizations.of` returns null and build throws.
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MemberEnginePanel(
          project: project,
          member: member,
          catalog: catalog,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('El del agente (Claude)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OpenRouter').last);
    await tester.pumpAndSettle();

    expect(find.text('OPENROUTER_API_KEY'), findsOneWidget);
    expect(find.text('Configurar'), findsOneWidget);
    expect(find.textContaining('Auto · Normal'), findsOneWidget);
    await tester.tap(find.textContaining('Default de OpenRouter'));
    await tester.pumpAndSettle();
    expect(find.text('GPT Test'), findsOneWidget);
    await tester.tap(find.text('GPT Test'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'ID exacto del modelo'),
      'anthropic/claude-test',
    );
    await tester.pump();
    expect(find.textContaining('anthropic/claude-test'), findsWidgets);
  });
}
