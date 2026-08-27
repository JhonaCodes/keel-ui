part of '../shared.dart';

/// Junta escrituras: N cambios de la misma clave adentro de una ventana corta
/// bajan a disco una sola vez.
///
/// Nació de un caso concreto. Un turno de un agente llega en pedazos —cada
/// trocito de texto es un cambio de estado— y cada uno guardaba. Con una
/// escritura que serializa y hace `fsync` sobre el hilo de la interfaz, una
/// respuesta larga era decenas de escrituras completas y la ventana se
/// ponía pastosa justo mientras había algo para leer.
///
/// Lo que se guarda al vencer la ventana es el estado de ESE momento, no el
/// de cuando se pidió: por eso [schedule] recibe una clave y no un valor.
/// Anotar el valor sería guardar una foto vieja.
///
/// Está acá afuera y no adentro de un ViewModel porque la parte difícil no
/// es guardar: es que una ráfaga se junte, que un `flush` puntual no espere
/// la ventana, y que cancelar de verdad cancele. Eso se puede probar solo, y
/// probado una vez sirve para cualquiera que lo necesite.
class CoalescedWrites {
  CoalescedWrites({required this.window, required this.write});

  /// Cuánto se juntan los cambios antes de bajar. Corta a propósito: esto es
  /// para agrupar una ráfaga, no para demorar el guardado.
  final Duration window;

  /// Qué hacer con una clave cuando le toca. Puede no encontrar nada —lo que
  /// se iba a guardar pudo borrarse mientras esperaba— y eso no es un error.
  final Future<void> Function(String key) write;

  final Set<String> _pending = {};
  Timer? _timer;

  /// Las claves que todavía no bajaron. Para mirar, no para tocar.
  Set<String> get pending => Set.unmodifiable(_pending);

  /// Anota que [key] cambió. Si ya hay una ventana abierta, viaja en esa.
  void schedule(String key) {
    _pending.add(key);
    if (_timer?.isActive ?? false) return;
    _timer = Timer(window, () => unawaited(_flushPending()));
  }

  /// Baja [key] YA, sin esperar la ventana. Para los momentos en que no hay
  /// un después: el turno terminó, la app se está cerrando.
  Future<void> flush(String key) async {
    _pending.remove(key);
    await write(key);
  }

  /// Olvida lo que quedó pendiente, sin escribirlo.
  ///
  /// Lo usa quien acaba de escribir todo por otro camino —borrar un elemento
  /// reescribe el conjunto entero— y no quiere que el timer vuelva a guardar
  /// algo que ya no está.
  void cancelPending() {
    _pending.clear();
    _timer?.cancel();
  }

  Future<void> _flushPending() async {
    final keys = [..._pending];
    _pending.clear();
    for (final key in keys) {
      await write(key);
    }
  }
}
