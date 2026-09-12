import 'dart:async';

/// Por qué se cortó un turno vigilado.
enum TurnWatchdogTrip {
  /// Pasó [TurnWatchdog.idle] sin que el proveedor emitiera un solo evento.
  idle,

  /// El turno lleva más de [TurnWatchdog.hard] corriendo, con o sin eventos.
  hard,
}

/// Vigila el stream de eventos de un turno y lo corta cuando se queda mudo.
///
/// Un CLI colgado no emite nada: ni texto, ni tool, ni `result`. Sin esto,
/// `await for` sobre sus eventos esperaba para siempre y la sesión quedaba
/// `running` con nada corriendo —la única salida era Stop a mano. Acá hay
/// dos plazos: uno de inactividad, que cada evento reinicia, y uno duro para
/// el turno entero. Cualquiera de los dos dispara [onTrip] UNA sola vez y
/// cierra el stream vigilado; quien lo escucha sale del `await for` como si
/// el proveedor hubiera terminado.
///
/// [pause] existe para el turno que está esperando a una persona: una
/// decisión pendiente no es inactividad del agente. Mientras está en pausa
/// no corre el plazo de inactividad, y si el plazo duro vence en ese lapso
/// se vuelve a armar completo al reanudar —la espera humana no le cuenta al
/// agente.
///
/// Es puro: no conoce sesiones ni proveedores, solo un stream y dos plazos.
/// Se usa desde `_runTurn` en `projects_viewmodel.dart`.
class TurnWatchdog {
  final Duration idle;
  final Duration hard;
  final void Function(TurnWatchdogTrip trip) onTrip;

  Timer? _idleTimer;
  Timer? _hardTimer;
  StreamSubscription<dynamic>? _subscription;
  StreamController<dynamic>? _controller;
  TurnWatchdogTrip? _trip;
  bool _paused = false;
  bool _hardDueWhilePaused = false;
  bool _finished = false;

  TurnWatchdog({
    required this.idle,
    required this.hard,
    required this.onTrip,
  });

  bool get tripped => _trip != null;

  TurnWatchdogTrip? get trip => _trip;

  /// Devuelve el mismo stream, con los plazos armados. Se llama una vez.
  Stream<T> guard<T>(Stream<T> source) {
    final controller = StreamController<T>(onCancel: _tearDown);
    _controller = controller;
    _subscription = source.listen(
      (event) {
        _armIdle();
        if (!controller.isClosed) controller.add(event);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      },
      onDone: () {
        _finished = true;
        _tearDown();
        if (!controller.isClosed) controller.close();
      },
    );
    _armHard();
    _armIdle();
    return controller.stream;
  }

  void pause() {
    if (_paused) return;
    _paused = true;
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  void resume() {
    if (!_paused) return;
    _paused = false;
    if (_finished || tripped) return;
    if (_hardDueWhilePaused) {
      _hardDueWhilePaused = false;
      _armHard();
    }
    _armIdle();
  }

  void _armIdle() {
    if (_paused || tripped || _finished) return;
    _idleTimer?.cancel();
    if (idle <= Duration.zero) return;
    _idleTimer = Timer(idle, () => _fire(TurnWatchdogTrip.idle));
  }

  void _armHard() {
    _hardTimer?.cancel();
    if (hard <= Duration.zero) return;
    _hardTimer = Timer(hard, () {
      if (_paused) {
        _hardDueWhilePaused = true;
        return;
      }
      _fire(TurnWatchdogTrip.hard);
    });
  }

  void _fire(TurnWatchdogTrip trip) {
    if (tripped || _finished) return;
    _trip = trip;
    _tearDown();
    onTrip(trip);
    final controller = _controller;
    if (controller != null && !controller.isClosed) controller.close();
  }

  void _tearDown() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _hardTimer?.cancel();
    _hardTimer = null;
    final subscription = _subscription;
    _subscription = null;
    subscription?.cancel();
  }
}
