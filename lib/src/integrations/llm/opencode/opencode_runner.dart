import 'dart:async';

import 'package:logger_rs/logger_rs.dart';

import 'package:keel_ui/src/integrations/llm/llm.dart';
import 'package:keel_ui/src/integrations/llm/opencode/opencode_serve_session.dart';

/// One OpenCode turn for a project node: a server for this turn only, one
/// prompt, its events until the session goes idle, then the server goes.
/// The 1:1 chat keeps the server between turns instead
/// (`OpenCodeServeSession` as a live session).
class OpenCodeRunner implements LlmRunner {
  const OpenCodeRunner();

  @override
  Stream<LlmEvent> run(
    LlmTurnSpec spec, {
    required String userPath,
    required Stream<void> cancel,
    Stream<String> steer = const Stream<String>.empty(),
    void Function(int pid)? onPidKnown,
  }) async* {
    // Before any await, so a cancel that arrives while the server starts is
    // not lost.
    var cancelled = false;
    LlmLiveSession? session;
    final cancelSubscription = cancel.listen((_) {
      cancelled = true;
      session?.kill();
    });
    try {
      try {
        session = await OpenCodeServeSession.start(
          spec,
          userPath: userPath,
          onPidKnown: onPidKnown,
        );
      } catch (error) {
        Log.e('Failed to start opencode serve', error: error);
        yield {'type': 'failure', 'message': 'No se pudo iniciar opencode: $error'};
        return;
      }
      if (cancelled) {
        session.kill();
        return;
      }
      session.send(spec.prompt);
      await for (final event in session.events) {
        switch (event['type']) {
          case 'turnEnded':
            return;
          case 'spontaneousTurn':
            continue;
          default:
            yield event;
        }
      }
    } finally {
      await cancelSubscription.cancel();
      await session?.close();
    }
  }
}
