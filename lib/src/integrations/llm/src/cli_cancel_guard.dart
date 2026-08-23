import 'dart:async';
import 'dart:io';

/// Cierra la ventana de carrera entre "llegó un cancel" y "ya existe el
/// `Process` al que matarle".
///
/// Un runner CLI arranca con al menos dos `await` antes de tener el
/// proceso (armar el workspace del turno, `Process.start`). El `cancel`
/// que le llega es un `StreamController.broadcast` de larga vida — si el
/// cancel se emitiera antes de que alguien lo escuche, ese evento se pierde
/// para siempre, sin replay. Suscribirse acá, como lo primero que hace el
/// runner, es lo único que cierra esa mitad de la ventana.
///
/// La otra mitad es simétrica: si el cancel llega mientras el proceso
/// todavía se está armando, el listener de abajo corre con `_process` en
/// null y no tiene nada que matar. Por eso [attach] vuelve a chequear
/// `_cancelled` apenas el proceso existe.
class CliCancelGuard {
  CliCancelGuard(Stream<void> cancel) {
    _subscription = cancel.listen((_) {
      _cancelled = true;
      _process?.kill();
    });
  }

  late final StreamSubscription<void> _subscription;
  Process? _process;
  bool _cancelled = false;

  /// Si ya se pidió cancelar — puede ser true incluso antes de [attach].
  bool get cancelled => _cancelled;

  /// Se llama apenas el proceso arranca. Si el cancel ya había llegado
  /// mientras tanto, lo mata acá mismo.
  void attach(Process process) {
    _process = process;
    if (_cancelled) process.kill();
  }

  Future<void> dispose() => _subscription.cancel();
}
