import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/agents/ui/widget/agent_activity_indicator.dart';
import 'package:keel_ui/src/modules/projects/model/session_live_turn.dart';
import 'package:keel_ui/src/modules/projects/model/session_subagent.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/turn_phase_label.dart';

/// Uses the same animated activity as the parent, driven by session state.
class SessionSubagentActivity extends StatelessWidget {
  const SessionSubagentActivity({super.key, required this.subagent});

  final SessionSubagent subagent;

  @override
  Widget build(BuildContext context) =>
      switch ((subagent.phase.livePhase, subagent.activity)) {
        (null, _) => const SizedBox.shrink(),
        (_, final activity?) => AgentActivityIndicator(activity: activity),
        (final phase?, null) => TurnPhaseLabel(
          phase: phase,
          accent: Theme.of(context).colorScheme.primary,
          compact: true,
        ),
      };
}

extension SubagentPhasePresentation on SubagentPhase {
  TurnPhase? get livePhase => switch (this) {
    .thinking => .thinking,
    .working => .working,
    .writing => .writing,
    .done || .failed || .unconfirmed => null,
  };
}
