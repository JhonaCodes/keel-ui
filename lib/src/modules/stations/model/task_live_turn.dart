import 'package:keel_ui/src/modules/agents/model/agent_tool_activity.dart';

/// The three things a member can be doing while it holds the turn. They are
/// distinct on purpose: "pensando" is reasoning you can open and read,
/// "escribiendo" is the answer landing in the thread, and "trabajando" is a
/// tool running — each one looks different, so each one reads differently.
enum TurnPhase { thinking, writing, working }

/// What is happening in a task *right now*: which member holds the turn, what
/// it is thinking, and which tool it has open.
///
/// In a 1:1 chat this lives on the agent, because there is only one. In a
/// station the thread is shared, so the live state has to name its owner —
/// "está leyendo un archivo" is useless when four agents share the channel and
/// you cannot tell which one.
///
/// Deliberately transient, like [StationTask.pendingPermission]: reasoning that
/// belongs to a turn that is no longer running is history, and history already
/// lives on the message it produced.
class TaskLiveTurn {
  final String profileId;
  final String? reasoning;
  final AgentToolActivity? activity;
  final TurnPhase phase;

  const TaskLiveTurn({
    required this.profileId,
    this.reasoning,
    this.activity,
    this.phase = TurnPhase.thinking,
  });

  TaskLiveTurn copyWith({
    String? reasoning,
    AgentToolActivity? activity,
    TurnPhase? phase,
    bool clearActivity = false,
    bool clearReasoning = false,
  }) {
    return TaskLiveTurn(
      profileId: profileId,
      reasoning: clearReasoning ? null : (reasoning ?? this.reasoning),
      activity: clearActivity ? null : (activity ?? this.activity),
      phase: phase ?? this.phase,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskLiveTurn &&
          runtimeType == other.runtimeType &&
          profileId == other.profileId &&
          reasoning == other.reasoning &&
          activity == other.activity &&
          phase == other.phase;

  @override
  int get hashCode => Object.hash(profileId, reasoning, activity, phase);

  @override
  String toString() =>
      'TaskLiveTurn(profileId: $profileId, '
      'reasoning: ${reasoning?.length ?? 0} chars, activity: $activity, '
      'phase: ${phase.name})';
}
