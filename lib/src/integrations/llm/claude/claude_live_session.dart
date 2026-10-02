import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger_rs/logger_rs.dart';

import 'package:keel_ui/src/core/services/claude_stream_events.dart';
import 'package:keel_ui/src/integrations/llm/claude/claude_arguments.dart';
import 'package:keel_ui/src/integrations/llm/claude/claude_launch.dart';
import 'package:keel_ui/src/integrations/llm/llm.dart';

/// One `claude` process kept alive across the turns of one conversation,
/// the way Claude Code keeps its own.
///
/// `claude -p <prompt>` per message paid ~2 s before the model saw anything
/// (node boot, SessionStart hooks, MCP handshakes) and started every turn
/// with a cold prompt cache. Here the process starts once with
/// `--input-format stream-json` and each turn is one line on stdin.
///
/// Where a turn ends is the delicate part. With a background task running,
/// the CLI emits a `result` as soon as the model yields, keeps working, and
/// emits another `result` after the task's notification re-invokes the model
/// (verified against CLI 2.1.280). Ending the turn at the first `result`
/// would leave work running with nothing on screen, so a turn ends at a
/// `result` only when no background task is pending — or, when the last task
/// finishes with the model idle, after [_reinvocationGrace] passes without
/// the model starting again.
class ClaudeLiveSession implements LlmLiveSession {
  ClaudeLiveSession._(this._process, this._launch);

  final Process _process;
  final ClaudeLaunch _launch;
  final ClaudeStreamReader _reader = ClaudeStreamReader();
  final StreamController<LlmEvent> _events = StreamController<LlmEvent>();
  final StringBuffer _stderrTail = StringBuffer();

  bool _turnActive = false;
  bool _modelActive = false;
  int _pendingBackgroundTasks = 0;
  bool _killed = false;
  Timer? _settleTimer;

  /// In the probe the model came back 70 ms after its last background task
  /// finished; two seconds is room for a loaded machine without keeping the
  /// chat busy for long when nothing is coming.
  static const _reinvocationGrace = Duration(seconds: 2);

  /// Enough of stderr to explain a crash, without growing for hours.
  static const _stderrTailChars = 4000;

  static Future<LlmLiveSession> start(
    LlmTurnSpec spec, {
    required String userPath,
    void Function(int pid)? onPidKnown,
  }) async {
    final launch = await ClaudeLaunch.prepare(spec);
    final Process process;
    try {
      process = await ClaudeLaunch.start(
        buildClaudeArguments(
          model: spec.model,
          effort: spec.effort,
          allowedTools: launch.allowedTools,
          systemPrompt: launch.systemPrompt,
          mcpConfigPath: launch.workspace.mcpConfigPath,
          claudeSettingsPath: launch.workspace.claudeSettingsPath,
          fullFileSystemAccess: spec.fullFileSystemAccess,
          sessionId: spec.sessionId,
          planMode: spec.planMode,
          maxTurns: spec.maxTurns,
          maxBudgetUsd: spec.maxBudgetUsd,
        ),
        workingDirectory: spec.workingDirectory,
        userPath: userPath,
      );
    } catch (error) {
      await launch.workspace.dispose();
      rethrow;
    }
    onPidKnown?.call(process.pid);
    return ClaudeLiveSession._(process, launch).._listen();
  }

  @override
  Stream<LlmEvent> get events => _events.stream;

  @override
  void send(String prompt) {
    _settleTimer?.cancel();
    _turnActive = true;
    _modelActive = true;
    _process.stdin.writeln(claudeUserLine(prompt));
  }

  @override
  void kill() {
    _killed = true;
    _process.kill();
  }

  @override
  Future<void> close() => _process.stdin.close();

  void _listen() {
    // A write to a process that already died fails here, not at the call.
    unawaited(
      _process.stdin.done.catchError(
        (Object error) => Log.w('stdin de claude cerrado: $error'),
      ),
    );
    // Drained all the time: a full stderr pipe blocks the process.
    _process.stderr
        .transform(utf8.decoder)
        .listen(
          _keepStderrTail,
          onError: (Object error) => Log.w('stderr de claude ilegible: $error'),
        );
    _process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          _onLine,
          onDone: () => unawaited(_onExit()),
          onError: (Object error) =>
              Log.e('Salida de claude ilegible', error: error),
        );
  }

  void _keepStderrTail(String chunk) {
    _stderrTail.write(chunk);
    if (_stderrTail.length <= _stderrTailChars) return;
    final text = _stderrTail.toString();
    _stderrTail
      ..clear()
      ..write(text.substring(text.length - _stderrTailChars));
  }

  void _onLine(String line) {
    if (line.trim().isEmpty) return;
    final Map<String, dynamic> event;
    try {
      event = jsonDecode(line) as Map<String, dynamic>;
    } catch (_) {
      Log.w('Unparseable claude output line: $line');
      return;
    }

    final type = event['type'] as String?;
    final subtype = event['subtype'] as String?;

    if (type == 'system' && subtype == 'background_tasks_changed') {
      _pendingBackgroundTasks = (event['tasks'] as List?)?.length ?? 0;
      if (_pendingBackgroundTasks == 0) _settleWhenIdle();
      return;
    }

    final startsModelWork =
        (type == 'system' && subtype == 'init') ||
        type == 'assistant' ||
        type == 'user';
    if (startsModelWork) {
      _settleTimer?.cancel();
      _modelActive = true;
      if (!_turnActive) {
        // Nobody sent anything: the model picked up on its own. It still
        // has to show as work in progress.
        _turnActive = true;
        _events.add({'type': 'spontaneousTurn'});
      }
    }

    for (final message in _reader.read(event)) {
      _events.add(message);
    }

    if (type == 'result') {
      _modelActive = false;
      if (_pendingBackgroundTasks == 0) _endTurn();
    }
  }

  void _settleWhenIdle() {
    if (!_turnActive || _modelActive) return;
    _settleTimer?.cancel();
    _settleTimer = Timer(_reinvocationGrace, () {
      if (!_modelActive && _pendingBackgroundTasks == 0) _endTurn();
    });
  }

  void _endTurn() {
    _settleTimer?.cancel();
    if (!_turnActive) return;
    _turnActive = false;
    _events.add({'type': 'turnEnded'});
  }

  Future<void> _onExit() async {
    _settleTimer?.cancel();
    final code = await _process.exitCode;
    if (_turnActive) {
      if (!_killed && code != 0) {
        final stderrText = _stderrTail.toString().trim();
        Log.e(
          'claude terminó con código $code a mitad de un turno. stderr: '
          '${stderrText.isEmpty ? '(vacío)' : stderrText}',
        );
        _events.add({
          'type': 'failure',
          'message': stderrText.isEmpty
              ? 'claude terminó con código $code'
              : stderrText,
        });
      }
      _endTurn();
    }
    await _launch.workspace.dispose();
    await _events.close();
  }
}
