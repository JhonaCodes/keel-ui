import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/shared/shared.dart';

void main() {
  /// Anota qué claves bajaron y en qué orden.
  ({CoalescedWrites writes, List<String> written}) unEscritor({
    Duration window = const Duration(milliseconds: 400),
  }) {
    final written = <String>[];
    return (
      writes: CoalescedWrites(
        window: window,
        write: (key) async => written.add(key),
      ),
      written: written,
    );
  }

  test('una ráfaga de la misma clave es UNA escritura', () {
    fakeAsync((async) {
      final (:writes, :written) = unEscritor();

      // Lo que pasa mientras un agente escribe: el texto llega en pedazos y
      // cada pedazo es un cambio de estado.
      for (var i = 0; i < 50; i++) {
        writes.schedule('keelai');
        async.elapse(const Duration(milliseconds: 5));
      }
      async.elapse(const Duration(seconds: 1));

      expect(written, ['keelai']);
    });
  });

  test('claves distintas bajan todas', () {
    fakeAsync((async) {
      final (:writes, :written) = unEscritor();

      writes.schedule('uno');
      writes.schedule('dos');
      async.elapse(const Duration(seconds: 1));

      expect(written, containsAll(['uno', 'dos']));
      expect(written, hasLength(2));
    });
  });

  test('nada baja antes de que venza la ventana', () {
    fakeAsync((async) {
      final (:writes, :written) = unEscritor();

      writes.schedule('uno');
      async.elapse(const Duration(milliseconds: 399));

      expect(written, isEmpty);
      expect(writes.pending, {'uno'});
    });
  });

  test('dos ráfagas separadas son dos escrituras', () {
    fakeAsync((async) {
      final (:writes, :written) = unEscritor();

      writes.schedule('uno');
      async.elapse(const Duration(seconds: 1));
      writes.schedule('uno');
      async.elapse(const Duration(seconds: 1));

      expect(written, ['uno', 'uno']);
    });
  });

  group('flush', () {
    test('baja ya, sin esperar la ventana', () {
      fakeAsync((async) {
        final (:writes, :written) = unEscritor();

        writes.schedule('uno');
        unawaited(writes.flush('uno'));
        async.flushMicrotasks();

        expect(written, ['uno']);
      });
    });

    test('y no la vuelve a escribir cuando vence', () {
      fakeAsync((async) {
        final (:writes, :written) = unEscritor();

        writes.schedule('uno');
        unawaited(writes.flush('uno'));
        async.elapse(const Duration(seconds: 1));

        expect(written, ['uno']);
      });
    });

    test('no arrastra a las otras que estaban esperando', () {
      fakeAsync((async) {
        final (:writes, :written) = unEscritor();

        writes.schedule('uno');
        writes.schedule('dos');
        unawaited(writes.flush('uno'));
        async.flushMicrotasks();

        expect(written, ['uno']);
        expect(writes.pending, {'dos'});
      });
    });
  });

  group('cancelar', () {
    test('lo pendiente no baja nunca', () {
      fakeAsync((async) {
        final (:writes, :written) = unEscritor();

        writes.schedule('uno');
        // Quien cancela es el que acaba de escribir todo por otro camino:
        // volver a guardar resucitaría algo que ya no está.
        writes.cancelPending();
        async.elapse(const Duration(seconds: 1));

        expect(written, isEmpty);
        expect(writes.pending, isEmpty);
      });
    });

    test('pero no rompe lo que venga después', () {
      fakeAsync((async) {
        final (:writes, :written) = unEscritor();

        writes.schedule('uno');
        writes.cancelPending();
        writes.schedule('dos');
        async.elapse(const Duration(seconds: 1));

        expect(written, ['dos']);
      });
    });
  });

  test('lo pendiente se puede mirar pero no tocar', () {
    final (:writes, written: _) = unEscritor();
    writes.schedule('uno');

    expect(() => writes.pending.add('dos'), throwsUnsupportedError);
  });
}
