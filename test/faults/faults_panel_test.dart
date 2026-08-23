import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/integrations/fault_journal/fault_journal.dart';

void main() {
  LocalDatabase.markUnavailable();

  final journal = FaultJournalService.instance.notifier;

  setUp(() async {
    await journal.ready;
    await journal.clear();
  });

  Future<void> abrir(WidgetTester tester) => tester.pumpWidget(
    const MaterialApp(home: FaultsPanel()),
  );

  /// Anotar toca el ViewModel y no la pantalla, así que va por afuera del
  /// reloj falso del test: adentro, un `await` que espera algo del mundo
  /// real no vuelve nunca.
  Future<void> anotar(
    WidgetTester tester, {
    required String message,
    String where = '',
    String detail = '',
  }) => tester.runAsync(
    () => journal.record(message: message, where: where, detail: detail),
  );

  testWidgets('sin fallas dice que no hay nada roto', (tester) async {
    await abrir(tester);

    expect(find.text('Nada roto por acá.'), findsOneWidget);
    // Nada que vaciar: el botón no está.
    expect(find.text('Vaciar'), findsNothing);
  });

  testWidgets('una falla se lee entera sin abrirla', (tester) async {
    await anotar(
      tester,
      message: 'El respaldo falló: no pude escribir el zip',
      where: 'vault_archive.dart:88',
      detail: 'el stack entero',
    );
    await abrir(tester);

    expect(
      find.text('El respaldo falló: no pude escribir el zip'),
      findsOneWidget,
    );
    expect(find.textContaining('vault_archive.dart:88'), findsOneWidget);
    // El detalle está guardado pero no ocupa la lista.
    expect(find.text('el stack entero'), findsNothing);
  });

  testWidgets('tocarla muestra el stack', (tester) async {
    await anotar(tester, message: 'reventó', detail: 'el stack entero');
    await abrir(tester);

    await tester.tap(find.text('reventó'));
    await tester.pump();

    expect(find.text('el stack entero'), findsOneWidget);
  });

  testWidgets('la que se repitió lo dice; la que pasó una vez no', (
    tester,
  ) async {
    await anotar(tester, message: 'una sola vez');
    await anotar(tester, message: 'y esta tres', where: 'x.dart:1');
    await anotar(tester, message: 'y esta tres', where: 'x.dart:1');
    await anotar(tester, message: 'y esta tres', where: 'x.dart:1');
    await abrir(tester);

    expect(find.text('×3'), findsOneWidget);
    expect(find.text('×1'), findsNothing);
  });
}
