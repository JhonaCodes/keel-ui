import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/integrations/app_update/app_update.dart';

void main() {
  LocalDatabase.markUnavailable();

  testWidgets('sin el código al lado lo dice, en vez de inventar una ruta', (
    tester,
  ) async {
    // El ejecutable de la corrida de tests vive en el SDK de Flutter, así
    // que arriba de él no hay ningún repo de Keel: es exactamente el caso
    // de una copia arrastrada a /Aplicaciones.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(children: const [KeelVersionSection()]),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('KEEL'), findsOneWidget);
    expect(
      find.textContaining('no tiene su código al lado'),
      findsOneWidget,
    );

    // Revisar sigue disponible —es gratis y puede cambiar la respuesta—;
    // traer no, porque no hay de dónde.
    expect(find.widgetWithText(TextButton, 'Revisar'), findsOneWidget);
    final traer = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Traer la versión nueva'),
    );
    expect(traer.onPressed, isNull);
  });
}
