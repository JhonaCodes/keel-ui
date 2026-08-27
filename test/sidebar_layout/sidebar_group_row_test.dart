import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/core/ui/running_dot.dart';
import 'package:keel_ui/src/modules/sidebar_layout/model/sidebar_layout.dart';
import 'package:keel_ui/src/modules/sidebar_layout/ui/widget/sidebar_group_row.dart';

void main() {
  Future<void> montar(
    WidgetTester tester, {
    required int runningCount,
    bool collapsed = true,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SidebarGroupRow(
            group: SidebarGroupSlot(
              id: 'g1',
              name: 'Clientes',
              memberIds: const ['a', 'b'],
              collapsed: collapsed,
            ),
            onToggle: () {},
            onRename: (_) => null,
            onUngroup: () {},
            runningCount: runningCount,
          ),
        ),
      ),
    );
  }

  testWidgets('un grupo plegado avisa que adentro hay trabajo', (tester) async {
    // Es el caso que motivó todo: con el grupo cerrado, su encabezado es lo
    // único que se ve, y no decía nada.
    await montar(tester, runningCount: 1);

    expect(find.byType(RunningDot), findsOneWidget);
  });

  testWidgets('sin nada corriendo no hay punto', (tester) async {
    await montar(tester, runningCount: 0);

    expect(find.byType(RunningDot), findsNothing);
  });

  testWidgets('con varios muestra cuántos', (tester) async {
    await montar(tester, runningCount: 3);

    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('con uno solo no escribe el número', (tester) async {
    // Un «1» al lado de un punto no agrega nada.
    await montar(tester, runningCount: 1);

    expect(find.text('1'), findsNothing);
  });

  testWidgets('el nombre del grupo se sigue viendo', (tester) async {
    await montar(tester, runningCount: 2);

    expect(find.text('Clientes'), findsOneWidget);
  });
}
