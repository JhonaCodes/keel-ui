import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/secrets/ui/screen/secrets_screen.dart';
import 'package:keel_ui/src/modules/secrets/viewmodel/secrets_viewmodel.dart';

void main() {
  LocalDatabase.markUnavailable();

  testWidgets('Secrets ofrece las credenciales fijas de proveedores LLM', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SecretsScreen()));
    await tester.pump();

    expect(find.text('OpenRouter'), findsOneWidget);
    expect(find.text('OPENROUTER_API_KEY'), findsOneWidget);
    expect(find.text('DeepSeek'), findsOneWidget);
    expect(find.text('DEEPSEEK_API_KEY'), findsOneWidget);
    expect(find.text('Configurar'), findsNWidgets(2));
  });

  testWidgets('una clave configurada nunca muestra ni precarga su valor', (
    tester,
  ) async {
    const token = 'openrouter-sensitive-token';
    SecretsService.instance.notifier.createSecret(
      name: 'OPENROUTER_API_KEY',
      description: '',
      value: token,
    );
    await tester.pumpWidget(const MaterialApp(home: SecretsScreen()));
    await tester.pump();

    expect(find.text('configurada'), findsOneWidget);
    expect(find.text('Reemplazar'), findsOneWidget);
    expect(find.textContaining(token), findsNothing);
  });
}
