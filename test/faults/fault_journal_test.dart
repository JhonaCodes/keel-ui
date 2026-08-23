import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/integrations/fault_journal/fault_journal.dart';

void main() {
  // Antes de tocar el ViewModel y no en un `setUpAll`: el singleton se
  // inicializa en cuanto alguien lo mira, y eso pasa en la línea siguiente.
  // Sin base, el diario tiene que seguir funcionando en memoria — que es
  // exactamente lo que hace en una máquina donde la base no abre.
  LocalDatabase.markUnavailable();

  final journal = FaultJournalService.instance.notifier;

  setUp(() async {
    await journal.ready;
    await journal.clear();
  });

  group('anotar', () {
    test('la misma falla dos veces es una falla que pasó dos veces', () async {
      await journal.record(message: 'no pude escribir', where: 'vault.dart:3');
      await journal.record(message: 'no pude escribir', where: 'vault.dart:3');

      expect(journal.data.faults, hasLength(1));
      expect(journal.data.faults.single.count, 2);
    });

    test('dos fallas distintas no se juntan aunque salgan del mismo lado',
        () async {
      await journal.record(message: 'una', where: 'vault.dart:3');
      await journal.record(message: 'otra', where: 'vault.dart:3');

      expect(journal.data.faults, hasLength(2));
      // La más nueva arriba: es la que se lee primero.
      expect(journal.data.faults.first.message, 'otra');
    });

    test('un mensaje vacío no ocupa una fila', () async {
      await journal.record(message: '   \n  ');
      expect(journal.data.faults, isEmpty);
    });

    test('se queda con la primera línea y tira el resto al detalle', () async {
      await journal.record(
        message: 'reventó\nen la línea 4\ny en la 5',
        detail: 'el stack entero',
      );

      expect(journal.data.faults.single.message, 'reventó');
      expect(journal.data.faults.single.detail, 'el stack entero');
    });

    test('no guarda más de las que entran', () async {
      for (var index = 0; index < FaultJournalViewModel.capacity + 5; index++) {
        await journal.record(message: 'falla $index');
      }

      expect(journal.data.faults, hasLength(FaultJournalViewModel.capacity));
      // Se van las viejas, no las nuevas.
      expect(
        journal.data.faults.first.message,
        'falla ${FaultJournalViewModel.capacity + 4}',
      );
    });
  });

  group('sin ver', () {
    test('cuenta las que no miraste', () async {
      await journal.record(message: 'una');
      await journal.record(message: 'otra');

      expect(journal.data.unseen, 2);

      await journal.markSeen();
      expect(journal.data.unseen, 0);
    });

    test('que se repita la vuelve a poner sin ver', () async {
      await journal.record(message: 'una');
      await journal.markSeen();
      expect(journal.data.unseen, 0);

      // Que ya hayas leído la primera no dice nada sobre que siga pasando.
      await journal.record(message: 'una');
      expect(journal.data.unseen, 1);
    });
  });

  group('de dónde salió', () {
    test('el primer archivo de Keel del stack, con su línea', () {
      const stack = '''
#0      _AssertionError._doThrowNew (dart:core-patch/errors_patch.dart:51:61)
#1      SystemVaultViewModel._guarded (package:keel_ui/src/integrations/system_vault/src/system_vault_viewmodel.dart:228:12)
#2      main (package:keel_ui/main.dart:70:5)
''';
      expect(faultOriginOf(StackTrace.fromString(stack)),
          'system_vault_viewmodel.dart:228');
    });

    test('se saltea el diario: si no, todo saldría de acá', () {
      const stack = '''
#0      _record (package:keel_ui/src/integrations/fault_journal/src/fault_capture.dart:99:3)
#1      SessionChatView.build (package:keel_ui/src/modules/projects/ui/view/session_chat_view.dart:412:7)
''';
      expect(faultOriginOf(StackTrace.fromString(stack)),
          'session_chat_view.dart:412');
    });

    test('sin stack no se inventa un origen', () {
      expect(faultOriginOf(null), '');
      expect(faultOriginOf(StackTrace.fromString('#0 algo (dart:async)')), '');
    });
  });

  group('copiar', () {
    test('lleva mensaje, origen, cuándo y el detalle', () {
      final fault = Fault(
        id: 'x',
        at: DateTime(2026, 8, 23, 10),
        lastAt: DateTime(2026, 8, 23, 10),
        message: 'reventó',
        where: 'algo.dart:12',
        detail: 'el stack',
        context: 'proyecto «keel-ui»',
      );

      expect(fault.asText, contains('reventó'));
      expect(fault.asText, contains('algo.dart:12'));
      expect(fault.asText, contains('proyecto «keel-ui»'));
      expect(fault.asText, contains('el stack'));
    });

    test('sobrevive a ir y volver de la base', () {
      final fault = Fault(
        id: 'x',
        at: DateTime(2026, 8, 23, 10),
        lastAt: DateTime(2026, 8, 23, 11),
        count: 3,
        message: 'reventó',
        where: 'algo.dart:12',
        seen: true,
      );

      final vuelta = Fault.fromJson(fault.toJson());
      expect(vuelta.count, 3);
      expect(vuelta.seen, isTrue);
      expect(vuelta.lastAt, fault.lastAt);
      expect(vuelta.where, 'algo.dart:12');
    });
  });
}
