import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:info_label/info_label.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/session_message_bubble.dart';

/// El hilo tiene que decir CUÁL de las dos cosas pasó. Un cierre bloqueado
/// —«Caso bloqueado en …», que es un resultado esperado del workflow— se
/// pintaba con el mismo rojo y el mismo ícono de excepción que un turno que
/// se cae, y el usuario lo leía como un crash de la app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalDatabase.markUnavailable();

  final at = DateTime(2026, 9, 7, 11, 20);

  Future<void> pumpNotice(WidgetTester tester, ChatRole role) async {
    await tester.pumpWidget(
      MaterialApp(
        // The widgets under test read AppLocalizations; without the
        // delegates `AppLocalizations.of` returns null and build throws.
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(),
        home: Scaffold(
          body: SessionMessageBubble(
            message: ChatMessage(
              role: role,
              text:
                  'Caso bloqueado en "Ejecutar la tanda, tarea por tarea": '
                  'el nodo cerró con evidencia y checklist.',
              timestamp: at,
              workNodeId: 'run-batch',
            ),
            projectId: 'project',
            sessionId: 'session',
            author: null,
            nodeTitle: null,
            askedBy: null,
            memberIndex: 0,
            askedByIndex: 0,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('un cierre bloqueado no usa el rojo ni el ícono de la falla', (
    tester,
  ) async {
    await pumpNotice(tester, ChatRole.blocked);

    final label = tester.widget<InfoLabel>(find.byType(InfoLabel));
    expect(label.typeInfoLabel, TypeInfoLabel.warning);
    expect(find.byIcon(Icons.block), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('una falla real de ejecución sí conserva el rojo y el error', (
    tester,
  ) async {
    await pumpNotice(tester, ChatRole.error);

    final label = tester.widget<InfoLabel>(find.byType(InfoLabel));
    expect(label.typeInfoLabel, TypeInfoLabel.error);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byIcon(Icons.block), findsNothing);
  });
}
