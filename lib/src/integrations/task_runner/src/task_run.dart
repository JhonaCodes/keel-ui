part of '../task_runner.dart';

/// A single in-flight CLI turn running in its own isolate. [events] streams
/// parsed turn events; [cancel] kills the underlying CLI process and tears
/// the isolate down.
class TaskRun {
  TaskRun._(this.events, this._onCancel, [this._onSteer]);

  final Stream<TaskEvent> events;
  final void Function() _onCancel;
  final bool Function(String text)? _onSteer;

  void cancel() => _onCancel();

  /// Whether this turn takes a message without being stopped.
  bool get canSteer => _onSteer != null;

  /// Hands [text] to the turn in flight, to enter at its next tool boundary.
  /// False when it could not be handed over (no steering, or the isolate is
  /// not listening yet): the caller keeps the message. True only means it
  /// was handed over — a [TaskSteerDelivered] with the same text confirms
  /// that it entered the turn.
  bool steer(String text) => _onSteer?.call(text) ?? false;
}

Future<TaskRun> _startTaskRun(TaskRunSpec spec) async {
  final receivePort = ReceivePort();
  final controller = StreamController<TaskEvent>();
  SendPort? commandPort;
  Isolate? isolate;

  void teardown() {
    receivePort.close();
    isolate?.kill(priority: Isolate.immediate);
  }

  receivePort.listen((message) {
    if (message is SendPort) {
      commandPort = message;
      return;
    }
    if (message is List && message.length == 2) {
      // Uncaught isolate error: [errorDescription, stackDescription].
      Log.e('task_runner isolate crashed: ${message.first}');
      controller.add(TaskFailure(message.first.toString()));
      controller.close();
      teardown();
      return;
    }
    if (message is Map) {
      final typedMessage = message.cast<String, dynamic>();
      if (typedMessage['type'] == 'done') {
        controller.close();
        teardown();
        return;
      }
      controller.add(TaskEvent.fromMessage(typedMessage));
    }
  });

  // Antes de levantar el isolate: adentro no se puede esperar a que un shell
  // de login conteste sin retrasar cada turno, y acá la lectura ya está
  // memoizada desde el primer probe de servicios.
  final userPath = await UserShellPath.resolved();

  isolate = await Isolate.spawn(
    _taskRunnerEntryPoint,
    _IsolateBootstrap(receivePort.sendPort, spec.toMessage(), userPath),
    onError: receivePort.sendPort,
  );

  bool sendSteer(String text) {
    final port = commandPort;
    if (port == null) return false;
    port.send({'type': 'steer', 'text': text});
    return true;
  }

  final steerable = dispatchLlmSteering(
    LlmProvider.fromLegacyAlias(spec.provider),
  );
  return TaskRun._(controller.stream, () {
    commandPort?.send({'type': 'cancel'});
  }, steerable ? sendSteer : null);
}
