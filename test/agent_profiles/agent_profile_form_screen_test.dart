import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/integrations/llm/openai_compatible/remote_model_catalog.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/ui/screen/agent_profile_form_screen.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalDatabase.markUnavailable();

  testWidgets('un perfil con el Haiku fechado de antes abre con su modelo, y '
      'al pasar a Codex no quedan modelos de Claude en la lista', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final home = Directory.systemTemp.createTempSync('cli_home');
    addTearDown(() => home.deleteSync(recursive: true));
    final catalog = RemoteModelCatalog(
      homeDirectory: home.path,
      codexHome: home.path,
      observedModels: () async => ['claude-opus-5-5'],
    );
    // Real I/O does not advance under the fake clock of a widget test.
    await tester.runAsync(() => catalog.load(AgentProvider.claude));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AgentProfileFormScreen(
          catalog: catalog,
          initial: AgentProfile(
            id: 'agent',
            name: 'coder',
            role: 'implementador',
            systemPrompt: '',
            model: 'claude-haiku-4-5-20251001',
            effort: 'medium',
            createdAt: DateTime(2026),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Haiku 4.5'), findsOneWidget);
    await tester.tap(find.text('Haiku 4.5'));
    await tester.pumpAndSettle();
    expect(find.text('Opus 5.5'), findsWidgets);
    await tester.tap(find.text('Haiku 4.5').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Claude'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Codex').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('El de tu config de codex'));
    await tester.pumpAndSettle();

    expect(find.text('Opus 5.5'), findsNothing);
  });
}
