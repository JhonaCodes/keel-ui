import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/projects/service/turn_watchdog.dart';

void main() {
  test('zero disables both timers while events and closure still work', () {
    fakeAsync((async) {
      final source = StreamController<int>();
      final trips = <TurnWatchdogTrip>[];
      final events = <int>[];
      var closed = false;
      TurnWatchdog(
        idle: Duration.zero,
        hard: Duration.zero,
        onTrip: trips.add,
      ).guard(source.stream).listen(events.add, onDone: () => closed = true);
      async.elapse(const Duration(days: 3));
      expect(trips, isEmpty);
      expect(closed, false);
      source.add(1);
      async.flushMicrotasks();
      expect(events, [1]);
      source.close();
      async.flushMicrotasks();
      expect(closed, true);
    });
  });

  group('TurnWatchdog', () {
    test('corta por inactividad una sola vez y cierra el stream', () {
      fakeAsync((async) {
        final source = StreamController<int>();
        final trips = <TurnWatchdogTrip>[];
        final received = <int>[];
        var closed = false;
        final watchdog = TurnWatchdog(
          idle: const Duration(minutes: 10),
          hard: const Duration(minutes: 45),
          onTrip: trips.add,
        );

        watchdog
            .guard(source.stream)
            .listen(received.add, onDone: () => closed = true);

        source.add(1);
        async.elapse(const Duration(minutes: 9));
        expect(trips, isEmpty, reason: 'nueve minutos no son inactividad');

        async.elapse(const Duration(minutes: 2));
        expect(trips, [TurnWatchdogTrip.idle]);
        expect(closed, isTrue);

        async.elapse(const Duration(hours: 1));
        expect(trips, hasLength(1), reason: 'un corte, no uno por timer');
        expect(received, [1]);
        source.close();
      });
    });

    test('un evento dentro de la ventana reinicia la inactividad', () {
      fakeAsync((async) {
        final source = StreamController<int>();
        final trips = <TurnWatchdogTrip>[];
        final watchdog = TurnWatchdog(
          idle: const Duration(minutes: 10),
          hard: const Duration(minutes: 45),
          onTrip: trips.add,
        );
        watchdog.guard(source.stream).listen((_) {});

        for (var i = 0; i < 4; i++) {
          async.elapse(const Duration(minutes: 8));
          source.add(i);
        }
        async.elapse(const Duration(minutes: 8));

        expect(trips, isEmpty);
        expect(watchdog.tripped, isFalse);
        source.close();
      });
    });

    test('el plazo duro corta aunque haya actividad', () {
      fakeAsync((async) {
        final source = StreamController<int>();
        final trips = <TurnWatchdogTrip>[];
        final watchdog = TurnWatchdog(
          idle: const Duration(minutes: 10),
          hard: const Duration(minutes: 45),
          onTrip: trips.add,
        );
        watchdog.guard(source.stream).listen((_) {});

        for (var i = 0; i < 10; i++) {
          async.elapse(const Duration(minutes: 5));
          source.add(i);
        }

        expect(trips, [TurnWatchdogTrip.hard]);
        source.close();
      });
    });

    test('en pausa no cuenta la inactividad', () {
      fakeAsync((async) {
        final source = StreamController<int>();
        final trips = <TurnWatchdogTrip>[];
        final watchdog = TurnWatchdog(
          idle: const Duration(minutes: 10),
          hard: const Duration(minutes: 45),
          onTrip: trips.add,
        );
        watchdog.guard(source.stream).listen((_) {});

        watchdog.pause();
        async.elapse(const Duration(minutes: 30));
        expect(trips, isEmpty, reason: 'esperar a la persona no es colgarse');

        watchdog.resume();
        async.elapse(const Duration(minutes: 11));
        expect(trips, [TurnWatchdogTrip.idle]);
        source.close();
      });
    });

    test('un stream que termina solo no dispara nada', () {
      fakeAsync((async) {
        final source = StreamController<int>();
        final trips = <TurnWatchdogTrip>[];
        final watchdog = TurnWatchdog(
          idle: const Duration(minutes: 10),
          hard: const Duration(minutes: 45),
          onTrip: trips.add,
        );
        watchdog.guard(source.stream).listen((_) {});

        source.add(1);
        source.close();
        async.elapse(const Duration(hours: 2));

        expect(trips, isEmpty);
      });
    });
  });
}
