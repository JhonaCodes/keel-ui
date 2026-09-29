part of '../task_runner.dart';

/// Main-isolate side of a live session: one worker isolate that owns one
/// provider process for a whole conversation, and the turns cut out of its
/// event stream.
///
/// Each turn is handed out as an ordinary [TaskRun], so whoever consumes it
/// cannot tell a live turn from a one-shot one: events until the turn ends,
/// then the stream closes. Cancelling a turn kills the process — Stop means
/// stop — and the next turn starts a new one that resumes the session.
class _LiveTaskSession {
  _LiveTaskSession({
    required this.spawnKey,
    required this.spawnSessionId,
    required this.label,
    required this.onSpontaneousTurn,
    required this.onClosed,
  });

  final String spawnKey;
  final String? spawnSessionId;

  /// Who the process runs for, as the Machine screen shows it.
  String label;

  void Function(TaskRun run) onSpontaneousTurn;
  final void Function() onClosed;

  final ReceivePort _receivePort = ReceivePort();
  final Completer<SendPort> _commandPort = Completer<SendPort>();
  final Completer<void> _started = Completer<void>();
  Isolate? _isolate;
  StreamController<TaskEvent>? _turn;
  String? _providerSessionId;
  int _pid = 0;
  bool _closed = false;
  Timer? _idleTimer;

  /// An idle process still holds a few hundred MB. After this long without
  /// a turn it exits on its own; the next message starts another one that
  /// resumes the same session. It never cuts a turn in progress.
  static const _idleLifetime = Duration(minutes: 30);

  Future<void> get started => _started.future;

  bool get isBusy => _turn != null;

  /// Whether a turn with [key] and [sessionId] can run on this process.
  bool serves(String key, String? sessionId) =>
      !_closed &&
      key == spawnKey &&
      (sessionId == null ||
          sessionId == (_providerSessionId ?? spawnSessionId));

  Future<void> start(TaskRunSpec spec) async {
    _receivePort.listen(_onMessage);
    try {
      // Resolved on this side: reading a login shell from inside the
      // isolate would delay every process start.
      final userPath = await UserShellPath.resolved();
      _isolate = await Isolate.spawn(
        _liveTaskRunnerEntryPoint,
        _IsolateBootstrap(_receivePort.sendPort, spec.toMessage(), userPath),
        onError: _receivePort.sendPort,
      );
      _armIdle();
    } catch (error) {
      Log.e('No se pudo abrir la sesión viva de $label', error: error);
      _finish();
    } finally {
      if (!_started.isCompleted) _started.complete();
    }
  }

  TaskRun startTurn(String prompt) {
    _idleTimer?.cancel();
    final turn = _openTurn();
    if (_closed) {
      turn
        ..add(const TaskFailure('La sesión del proveedor se cerró.'))
        ..close();
      _turn = null;
    } else {
      unawaited(_send({'type': 'turn', 'prompt': prompt}));
    }
    return TaskRun._(turn.stream, _cancel);
  }

  void close() {
    _idleTimer?.cancel();
    unawaited(_send({'type': 'close'}));
  }

  StreamController<TaskEvent> _openTurn() {
    final turn = StreamController<TaskEvent>();
    _turn = turn;
    return turn;
  }

  void _cancel() => unawaited(_send({'type': 'cancel'}));

  Future<void> _send(Map<String, dynamic> command) async {
    if (_closed) return;
    final port = await _commandPort.future;
    if (!_closed) port.send(command);
  }

  void _onMessage(Object? message) {
    if (message is SendPort) {
      if (!_commandPort.isCompleted) _commandPort.complete(message);
      return;
    }
    if (message is List && message.length == 2) {
      // Uncaught isolate error: [errorDescription, stackDescription].
      Log.e('live task isolate crashed: ${message.first}');
      _turn?.add(TaskFailure(message.first.toString()));
      _finish();
      return;
    }
    if (message is! Map) return;
    final event = message.cast<String, dynamic>();
    switch (event['type']) {
      case 'processStarted':
        _pid = event['pid'] as int;
        RunningProcesses.register(_pid, label);
      case 'spontaneousTurn':
        _idleTimer?.cancel();
        onSpontaneousTurn(TaskRun._(_openTurn().stream, _cancel));
      case 'turnEnded':
        unawaited(_turn?.close());
        _turn = null;
        _armIdle();
      case 'done':
        _finish();
      default:
        if (event['type'] == 'sessionStarted') {
          _providerSessionId = event['sessionId'] as String?;
        }
        final turn = _turn;
        if (turn == null) {
          // A failure with no turn open (the process died while idle, or
          // never started) still has to be seen by someone.
          Log.w('Evento de $label sin turno abierto: ${event['type']}');
          return;
        }
        turn.add(TaskEvent.fromMessage(event));
    }
  }

  void _armIdle() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleLifetime, close);
  }

  void _finish() {
    if (_closed) return;
    _closed = true;
    _idleTimer?.cancel();
    unawaited(_turn?.close());
    _turn = null;
    if (_pid != 0) RunningProcesses.unregister(_pid);
    _receivePort.close();
    _isolate?.kill(priority: Isolate.immediate);
    onClosed();
  }
}
