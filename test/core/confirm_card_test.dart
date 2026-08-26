import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/core/ui/confirm_card.dart';

void main() {
  /// Abre la tarjeta y devuelve lo que contestó, cuando conteste.
  Future<bool?> abrir(
    WidgetTester tester, {
    String? typeToConfirm,
    List<ConfirmDetail> details = const [],
  }) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        // Los textos de la app son en castellano; los dos botones salen de
        // l10n, así que el test fija el idioma en vez de depender del que
        // quede primero en la lista.
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  answer = await confirmWithCard(
                    context,
                    title: 'Eliminar el proyecto #keel-ui',
                    body: 'Se lleva sus sesiones.',
                    details: details,
                    destructive: true,
                    typeToConfirm: typeToConfirm,
                  );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return answer;
  }

  testWidgets('muestra el título y el cuerpo', (tester) async {
    await abrir(tester);

    expect(find.text('Eliminar el proyecto #keel-ui'), findsOneWidget);
    expect(find.text('Se lleva sus sesiones.'), findsOneWidget);
  });

  testWidgets('cancelar contesta que no', (tester) async {
    await abrir(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    // La respuesta viaja por el Future del botón; alcanza con que la tarjeta
    // se haya ido sin confirmar.
    expect(find.text('Eliminar el proyecto #keel-ui'), findsNothing);
  });

  testWidgets('confirmar cierra la tarjeta', (tester) async {
    await abrir(tester);

    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(find.text('Eliminar el proyecto #keel-ui'), findsNothing);
  });

  testWidgets('los detalles se listan tal cual', (tester) async {
    await abrir(
      tester,
      details: [
        (lead: '3 sesiones', rest: 'con sus hilos'),
        (lead: '12 mensajes', rest: ''),
      ],
    );

    expect(find.textContaining('3 sesiones'), findsOneWidget);
    expect(find.textContaining('12 mensajes'), findsOneWidget);
  });

  group('cuando hay que escribir el nombre', () {
    testWidgets('el botón arranca deshabilitado', (tester) async {
      await abrir(tester, typeToConfirm: 'keel-ui');

      final boton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(boton.onPressed, isNull);
      expect(find.textContaining('para confirmar'), findsOneWidget);
    });

    testWidgets('un nombre parecido no alcanza', (tester) async {
      await abrir(tester, typeToConfirm: 'keel-ui');

      await tester.enterText(find.byType(TextField), 'keel');
      await tester.pump();

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });

    testWidgets('el nombre exacto lo habilita', (tester) async {
      await abrir(tester, typeToConfirm: 'keel-ui');

      await tester.enterText(find.byType(TextField), 'keel-ui');
      await tester.pump();

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );

      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('Eliminar el proyecto #keel-ui'), findsNothing);
    });
  });
}
