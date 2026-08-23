import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/app_status/model/app_status.dart';
import 'package:keel_ui/src/modules/app_status/viewmodel/app_status_viewmodel.dart';

void main() {
  group('lo que bloquea y lo que solo avisa', () {
    test('during atenúa la app; inBackground no', () async {
      final status = AppStatusViewModel();

      late AppStatusState duranteBloqueo;
      await status.during('Restaurando el respaldo', () async {
        duranteBloqueo = status.data;
      });
      expect(duranteBloqueo.busy, isTrue);
      expect(duranteBloqueo.label, 'Restaurando el respaldo');

      late AppStatusState duranteFondo;
      await status.inBackground('Respaldando el sistema', () async {
        duranteFondo = status.data;
      });
      expect(duranteFondo.busy, isFalse);
      expect(duranteFondo.working, isTrue);
      expect(duranteFondo.label, 'Respaldando el sistema');
    });

    test('las dos se limpian al terminar', () async {
      final status = AppStatusViewModel();
      await status.during('a', () async {});
      await status.inBackground('b', () async {});
      expect(status.data.busy, isFalse);
      expect(status.data.working, isFalse);
      expect(status.data.label, isNull);
    });

    // El modo de falla de todo indicador global hecho a mano: una tarea que
    // explota deja la app oscurecida para siempre.
    test('una tarea que explota no deja la app trabada', () async {
      final status = AppStatusViewModel();
      await expectLater(
        status.during('a', () async => throw StateError('tronó')),
        throwsStateError,
      );
      expect(status.data.busy, isFalse);

      await expectLater(
        status.inBackground('b', () async => throw StateError('tronó')),
        throwsStateError,
      );
      expect(status.data.working, isFalse);
    });

    test('dos tareas que se solapan no se apagan entre ellas', () async {
      final status = AppStatusViewModel();
      final primera = status.during(
        'larga',
        () => Future.delayed(const Duration(milliseconds: 40)),
      );
      final segunda = status.during('larga', () async {});
      await segunda;
      // La corta terminó, pero la larga sigue: el contador la sostiene.
      expect(status.data.busy, isTrue);
      await primera;
      expect(status.data.busy, isFalse);
    });

    test('un fondo no apaga un bloqueo que sigue corriendo', () async {
      final status = AppStatusViewModel();
      final bloqueo = status.during(
        'restaurar',
        () => Future.delayed(const Duration(milliseconds: 40)),
      );
      await status.inBackground('respaldar', () async {});
      expect(status.data.busy, isTrue);
      expect(status.data.working, isFalse);
      // Con las dos corriendo, la que se nombra es la que bloquea.
      expect(status.data.label, 'restaurar');
      await bloqueo;
    });
  });
}
