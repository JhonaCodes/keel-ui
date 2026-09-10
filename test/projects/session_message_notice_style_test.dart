import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_notice_bubble.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/markdown_text.dart';
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

    expect(_accentOf(tester), AppColors.brass);
    expect(find.byIcon(Icons.block), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNothing);
    expect(find.text('ADVERTENCIA'), findsOneWidget);
  });

  testWidgets('la nota se lee como una burbuja: marco, firma y markdown', (
    tester,
  ) async {
    await pumpNotice(tester, ChatRole.blocked);

    // Marco de burbuja, no cartel plano: borde del tono y esquinas del chat.
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(ChatNoticeBubble),
        matching: find.byType(Container),
      ).first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(12));

    // La firma Keel: la nota la escribió la app, no el agente.
    expect(find.byType(Image), findsOneWidget);

    // El cuerpo pasa por el renderer de markdown —viñetas y código en
    // línea— y no por un Text crudo: era la razón por la que un informe
    // largo salía como un muro ilegible.
    final body = tester.widget<MarkdownText>(find.byType(MarkdownText));
    expect(body.text, contains('Caso bloqueado'));
    // Y va sobre la tinta normal, no teñido del color del tono.
    expect(body.color, isNot(AppColors.brass));
  });

  testWidgets('el hilo se puede copiar: la nota entra en la selección', (
    tester,
  ) async {
    // El hilo envuelve TODO el ListView en un SelectionArea
    // (session_chat_view.dart) para que se pueda arrastrar la selección a
    // través de varios mensajes. Una nota que renderizara su texto de una
    // forma que no participa de la selección quedaría como un agujero en el
    // medio del hilo: se copiaría lo de arriba y lo de abajo, y justo el
    // informe que uno quiere pegar, no.
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(),
        home: Scaffold(
          body: SelectionArea(
            child: ListView(
              children: const [
                ChatNoticeBubble(
                  role: ChatRole.blocked,
                  text: 'Caso bloqueado: el checklist quedó incompleto.',
                  fontSize: 13,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // La nota vive DENTRO del área de selección.
    expect(
      find.ancestor(
        of: find.byType(ChatNoticeBubble),
        matching: find.byType(SelectionArea),
      ),
      findsOneWidget,
    );

    // Y el texto se copia DE VERDAD: seleccionar todo y copiar tiene que
    // dejar el contenido de la nota en el portapapeles. Es el oráculo real
    // de «se puede copiar el hilo»; que exista un SelectionArea alrededor no
    // prueba que lo de adentro participe de la selección.
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final region = tester.state<SelectableRegionState>(
      find.byType(SelectableRegion),
    );
    region.selectAll(SelectionChangedCause.keyboard);
    await tester.pump();
    // El mismo intent que dispara Cmd+C sobre la selección, en vez del
    // método deprecado: es el camino que recorre el usuario.
    Actions.invoke(
      tester.element(find.byType(ChatNoticeBubble)),
      CopySelectionTextIntent.copy,
    );
    await tester.pump();

    expect(copied, contains('el checklist quedó incompleto'));
  });

  testWidgets('una falla real de ejecución sí conserva el rojo y el error', (
    tester,
  ) async {
    await pumpNotice(tester, ChatRole.error);

    expect(_accentOf(tester), isNot(AppColors.brass));
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byIcon(Icons.block), findsNothing);
    expect(find.text('FALLA'), findsOneWidget);
  });
}

/// El color con el que la nota se enmarca, leído del borde real de la
/// burbuja: es lo que distingue una advertencia de una falla a simple vista.
Color _accentOf(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.descendant(
      of: find.byType(ChatNoticeBubble),
      matching: find.byType(Container),
    ).first,
  );
  final decoration = container.decoration! as BoxDecoration;
  return decoration.border!.top.color;
}
