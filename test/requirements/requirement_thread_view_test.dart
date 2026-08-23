import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/requirements/model/internal_requirement.dart';
import 'package:keel_ui/src/modules/requirements/ui/view/requirement_thread_view.dart';

InternalRequirement _requerimiento({List<RequirementEntry> thread = const []}) {
  final ahora = DateTime(2026, 8, 23, 17);
  return InternalRequirement(
    id: 'req-1',
    code: 'REQ-0001',
    title: 'Implementar soporte i18n: inglés + español colombiano',
    fromProjectId: 'p-origen',
    toProjectId: 'p-destino',
    need: 'Traducir toda la interfaz a dos idiomas.',
    context: 'Hay 665 strings en 315 archivos, todos en español.',
    openedByHandle: 'i18n-analista',
    openedInSessionId: 's-1',
    createdAt: ahora,
    updatedAt: ahora,
    thread: thread,
  );
}

void main() {
  LocalDatabase.markUnavailable();

  Future<void> abrir(
    WidgetTester tester,
    InternalRequirement requirement,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RequirementThreadView(requirement: requirement),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('el hilo se abre sin reventar el layout', (tester) async {
    // El caso que colgaba la app: una franja del hilo dentro de un
    // scroll. La barra de color se estiraba a lo alto de una caja sin
    // alto, y eso tira una excepción de layout POR FRANJA Y POR FRAME —
    // con el volcado del árbol entero cada vez, que es lo que deja la
    // ventana sin responder.
    await abrir(
      tester,
      _requerimiento(
        thread: [
          for (var index = 0; index < 6; index++)
            RequirementEntry(
              id: 'e$index',
              side: index.isEven
                  ? RequirementSide.destino
                  : RequirementSide.origen,
              kind: RequirementEntryKind.avance,
              text: 'Entrada número $index del hilo.',
              authorHandle: 'i18n-traductor',
            createdAt: DateTime(2026, 8, 23, 17, index),
            ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('REQ-0001'), findsOneWidget);
    expect(find.text('Entrada número 5 del hilo.'), findsOneWidget);
  });

  testWidgets('sin entradas tampoco: el pedido ya es una franja', (
    tester,
  ) async {
    await abrir(tester, _requerimiento());

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Traducir toda la interfaz'), findsOneWidget);
  });
}
