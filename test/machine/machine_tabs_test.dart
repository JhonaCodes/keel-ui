import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/machine/model/machine_tab.dart';
import 'package:keel_ui/src/modules/machine/ui/widget/machine_tabs.dart';

/// Máquina separa sus contextos en pestañas: se abre en Cuentas, y cada
/// pestaña muestra solo lo suyo en vez de una lista con todo mezclado.
void main() {
  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: MachineTabs(
        title: 'Máquina',
        actions: const [],
        pages: {
          for (final tab in MachineTab.values)
            tab: Text('página ${tab.name}'),
        },
      ),
    ),
  );

  testWidgets('opens on Cuentas and shows one context at a time', (
    tester,
  ) async {
    await pump(tester);

    for (final label in ['Cuentas', 'Consumo', 'Instalado', 'Equipo']) {
      expect(
        find.descendant(of: find.byType(TabBar), matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(find.text('página accounts'), findsOneWidget);
    expect(find.text('página hardware'), findsNothing);

    await tester.tap(find.text('Equipo'));
    await tester.pumpAndSettle();

    expect(find.text('página hardware'), findsOneWidget);
    expect(find.text('página accounts'), findsNothing);
  });
}
