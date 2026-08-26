import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/catalog_locks/model/catalog_lock.dart';
import 'package:keel_ui/src/modules/catalog_locks/ui/screen/catalog_locks_screen.dart';
import 'package:keel_ui/src/modules/catalog_locks/viewmodel/catalog_locks_viewmodel.dart';

void main() {
  LocalDatabase.markUnavailable();

  final locks = CatalogLocksService.instance.notifier;

  setUp(() async {
    await locks.ready;
    for (final lock in [...locks.data.locks]) {
      if (lock.kind == CatalogLockKind.lockRegistry) continue;
      await locks.setLocked(lock.kind, lock.name, locked: false);
    }
  });

  Future<void> abrir(WidgetTester tester) =>
      tester.pumpWidget(const MaterialApp(home: CatalogLocksScreen()));

  /// Bloquear toca el ViewModel, no la pantalla: va por afuera del reloj
  /// falso del test, misma razón que el panel de fallas.
  Future<void> bloquear(
    WidgetTester tester,
    CatalogLockKind kind,
    String name,
  ) => tester.runAsync(() => locks.setLocked(kind, name, locked: true));

  testWidgets('sin candados propios explica para qué sirven', (tester) async {
    await abrir(tester);

    expect(find.textContaining('No bloqueaste nada todavía'), findsOneWidget);
    expect(find.text('Desbloquear'), findsNothing);
  });

  testWidgets('lo bloqueado aparece agrupado por tipo', (tester) async {
    await bloquear(tester, CatalogLockKind.rule, 'tdd-obligatorio');
    await bloquear(tester, CatalogLockKind.skill, 'formato-de-tareas');
    await abrir(tester);

    expect(find.text('REGLA'), findsOneWidget);
    expect(find.text('SKILL'), findsOneWidget);
    expect(find.text('tdd-obligatorio'), findsOneWidget);
    expect(find.text('formato-de-tareas'), findsOneWidget);
  });

  testWidgets('el botón lo saca de la lista', (tester) async {
    await bloquear(tester, CatalogLockKind.rule, 'tdd-obligatorio');
    await abrir(tester);

    await tester.tap(find.byTooltip('Desbloquear'));
    await tester.pump();

    expect(find.text('tdd-obligatorio'), findsNothing);
    expect(locks.isLocked(CatalogLockKind.rule, 'tdd-obligatorio'), isFalse);
  });

  testWidgets('el registro del sistema se muestra y no se puede sacar', (
    tester,
  ) async {
    await bloquear(tester, CatalogLockKind.rule, 'tdd-obligatorio');
    await abrir(tester);

    expect(find.text('DEL SISTEMA'), findsOneWidget);
    expect(find.textContaining('El registro de candados'), findsOneWidget);
    // Un solo botón: el de la regla. El registro no tiene con qué sacarse.
    expect(find.byTooltip('Desbloquear'), findsOneWidget);
  });
}
