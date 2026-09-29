part of '../llm.dart';

/// One provider process kept alive across the turns of one conversation.
///
/// Only targets whose CLI can take the next message without restarting
/// implement it — see `dispatchLlmLiveSession`. The per-turn [LlmRunner]
/// pays process boot, hooks and MCP handshakes on every message; a live
/// session pays them once.
///
/// [events] carries the same normalized [LlmEvent]s a runner emits, plus two
/// transport markers the task runner consumes and never forwards to the app:
/// `turnEnded` (the turn that [send] opened is over) and `spontaneousTurn`
/// (the provider started working on its own, e.g. a background task finished
/// and re-invoked the model). The stream closes when the process exits.
abstract interface class LlmLiveSession {
  Stream<LlmEvent> get events;

  /// Opens a turn with [prompt] as the user's message.
  void send(String prompt);

  /// Stops the process now. Used for Stop: the next turn starts a new
  /// process that resumes the same provider session.
  void kill();

  /// Lets the process finish and exit on its own.
  Future<void> close();
}
