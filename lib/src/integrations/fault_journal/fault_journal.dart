/// El diario de fallas: todo lo que se rompió, en un lugar que se mira.
///
/// Hasta acá, una excepción de la app terminaba en la consola —cuarenta y
/// pico de `Log.e` repartidos por el código— y la consola solo existe si
/// arrancaste Keel desde una terminal y todavía la tenés abierta. Un
/// respaldo que falla, un índice que no se pudo escribir o un flujo que se
/// cortó a las tres de la mañana no dejaban rastro en ningún lado que se
/// pueda abrir después.
///
/// Acá se juntan las tres fuentes que hoy existen, sin tocar las cuarenta y
/// pico de llamadas:
///
/// | De dónde viene | Cómo entra |
/// |---|---|
/// | `Log.e` / `Log.f` en cualquier archivo | el listener de `Logger.root` |
/// | Un error de build o de layout | `FlutterError.onError` |
/// | Una excepción asíncrona sin dueño | `PlatformDispatcher.onError` |
///
/// Lo que NO hace: mandar nada afuera. Keel no tiene servidor ni cuenta, y
/// una falla que se sube a algún lado es una falla que viaja con las rutas
/// de tus proyectos adentro. El diario vive en la misma base local que todo
/// el resto, y el aviso es un punto rojo en el rail —más, si la ventana no
/// está enfocada, una notificación de macOS.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger_rs/logger_rs.dart';
import 'package:logging/logging.dart' show Level, Logger;
import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:window_manager/window_manager.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/shared/shared.dart';

part 'src/fault.dart';
part 'src/fault_capture.dart';
part 'src/fault_notice.dart';
part 'src/ui/faults_panel.dart';

/// Todo lo que falló, lo más nuevo arriba.
class FaultJournalViewModel extends ViewModel<FaultJournalState> {
  FaultJournalViewModel() : super(const FaultJournalState());

  /// Cuánto se guarda. Una falla de hace dos meses ya no se arregla: se
  /// leyó o no se leyó.
  static const retention = Duration(days: 30);

  /// Cuántas caben. El tope importa más que la ventana de tiempo: un bug de
  /// layout escribe una falla POR FRAME, y aunque las repetidas se junten,
  /// dos bugs alternándose no se juntan.
  static const capacity = 200;

  /// Cuánto se espera antes de volver a avisar de la MISMA falla.
  static const _kRepeatQuiet = Duration(seconds: 1);

  FaultJournalRepository get _repository => FaultJournalRepository();

  Future<void>? _ready;
  Future<void> get ready => _ready ??= _loadPersisted();

  /// Si la base todavía deja escribir.
  ///
  /// Una escritura que falla apaga esto para siempre y el diario sigue en
  /// memoria. No es pereza: `LocalDatabase` avisa de sus propias fallas por
  /// `Log.e`, o sea por acá, así que reintentar es anotar que no se pudo
  /// anotar, en un bucle que se come la app justo cuando ya algo andaba mal.
  bool _persists = true;

  /// Mientras se publica un estado nuevo. Publicar redibuja, redibujar
  /// puede reventar, y eso vuelve a entrar acá.
  bool _publishing = false;

  DateTime? _publishedAt;

  @override
  void init() {
    if (_ready == null) updateSilently(const FaultJournalState());
    unawaited(ready);
  }

  Future<void> _loadPersisted() async {
    try {
      final faults = await _repository.load();
      updateState(FaultJournalState(faults: faults));
    } catch (error) {
      // Con `debugPrint` y no con `Log.e`: el listener que alimenta esto ya
      // está puesto, y una base que no abre escribiría una falla por cada
      // intento de leerla.
      debugPrint('No pude leer el diario de fallas: $error');
    }
  }

  /// Anota una falla. Es el único camino de entrada, y no espera a nadie:
  /// anotar que algo se rompió no puede romper nada más.
  Future<void> record({
    required String message,
    String where = '',
    String detail = '',
    String context = '',
  }) async {
    final clean = _oneLine(message);
    if (clean.isEmpty || _publishing) return;
    await ready;

    final now = DateTime.now();
    final previous = data.faults.firstOrNull;

    // La misma falla dos veces seguidas es UNA falla que pasó dos veces.
    // Sin esto, un error de build llena las doscientas filas en tres
    // segundos y se lleva puesto todo lo que había antes.
    if (previous != null && previous.sameAs(clean, where)) {
      final bumped = previous.again(now);
      final state = FaultJournalState(
        faults: [bumped, ...data.faults.skip(1)],
      );
      // Un error de layout falla UNA VEZ POR FRAME, y publicar redibuja:
      // avisar de cada repetición es pedirle a la pantalla que se dibuje de
      // nuevo para contar que dibujarse falló. El contador se guarda igual;
      // lo que se espacia es el aviso.
      if (_since(_publishedAt) > _kRepeatQuiet) {
        _publish(state);
      } else {
        updateSilently(state);
      }
      await _write(() => _repository.save(bumped));
      return;
    }

    final fault = Fault(
      id: generateUuidV4(),
      at: now,
      lastAt: now,
      where: where,
      message: clean,
      detail: _capped(detail),
      context: context,
    );

    final cutoff = now.subtract(retention);
    final vivas = [
      fault,
      for (final existing in data.faults)
        if (existing.lastAt.isAfter(cutoff)) existing,
    ];
    final sobran = vivas.length > capacity
        ? vivas.sublist(capacity)
        : const <Fault>[];

    _publish(
      FaultJournalState(faults: vivas.take(capacity).toList(growable: false)),
    );
    await _write(() => _repository.save(fault));
    for (final vieja in sobran) {
      await _write(() => _repository.remove(vieja.id));
    }
    unawaited(noticeOf(fault));
  }

  /// Las marca vistas. Lo llama el panel al abrirse: mirarlas ES verlas, y
  /// pedir además un click en "ya lo vi" es pedir dos veces lo mismo.
  Future<void> markSeen() async {
    final pendientes = data.faults.where((fault) => !fault.seen).toList();
    if (pendientes.isEmpty) return;

    _publish(
      FaultJournalState(
        faults: [for (final fault in data.faults) fault.asSeen()],
      ),
    );
    // Solo se reescribe lo que cambió: marcar doscientas filas cuando
    // cambiaron tres es una escritura por fila para nada.
    for (final fault in pendientes) {
      await _write(() => _repository.save(fault.asSeen()));
    }
  }

  /// Vacía el diario. Es una decisión del usuario y no hay deshacer: lo que
  /// se borra acá ya se leyó.
  Future<void> clear() async {
    if (data.faults.isEmpty) return;
    _publish(const FaultJournalState());
    await _write(_repository.clear);
  }

  void _publish(FaultJournalState state) {
    _publishing = true;
    try {
      updateState(state);
      _publishedAt = DateTime.now();
    } finally {
      _publishing = false;
    }
  }

  Future<void> _write(Future<void> Function() work) async {
    if (!_persists) return;
    try {
      await work();
    } catch (error) {
      _persists = false;
      debugPrint('El diario de fallas dejó de guardarse en disco: $error');
    }
  }

  static Duration _since(DateTime? at) =>
      at == null ? const Duration(days: 1) : DateTime.now().difference(at);
}

mixin FaultJournalService {
  static final ReactiveNotifier<FaultJournalViewModel> instance =
      ReactiveNotifier<FaultJournalViewModel>(() => FaultJournalViewModel());
}
