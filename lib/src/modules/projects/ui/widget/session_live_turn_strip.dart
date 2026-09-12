import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agents/model/agent_tool_activity.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/agent_activity_indicator.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/reasoning_panel.dart';
import 'package:keel_ui/src/modules/projects/model/member_color.dart';
import 'package:keel_ui/src/modules/projects/model/session_live_turn.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/turn_phase_label.dart';

/// How far the text sits from the left edge: avatar width plus its gap, so
/// everything under the header lines up with the handle above it.
const _kIndent = 38.0;

/// What the member holding the turn is doing, right now, above the composer.
///
/// The 1:1 chat shows the same states, but it can leave them anonymous —
/// there is only ever one agent. Here they are prefixed by the member's avatar
/// and handle in its own colour: in a shared thread, "leyendo un archivo" says
/// nothing until you know which of the four is reading.
class SessionLiveTurnStrip extends StatelessWidget {
  const SessionLiveTurnStrip({
    super.key,
    required this.turn,
    required this.members,
  });

  final SessionLiveTurn turn;
  final List<AgentProfile> members;

  @override
  Widget build(BuildContext context) {
    final memberIds = [for (final member in members) member.id];
    final index = memberIds.indexOf(turn.profileId);
    if (index < 0) return const SizedBox.shrink();

    final member = members[index];
    final accent = memberColorFor(index);
    final reasoning = turn.reasoning;
    final activity = turn.activity;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Centred, not top-aligned: the avatar, the handle, the state and
          // the animated tool icon all sit on the avatar's midline, so the
          // strip reads as one line about one agent.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Semantics(
                label: AppLocalizations.of(context).sessionTurnOpen,
                child: _LiveMemberAvatar(accent: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LiveHeader(
                  name: member.name,
                  accent: accent,
                  phase: turn.phase,
                  activity: activity,
                  awaitingOutput: turn.awaitingOutput,
                ),
              ),
            ],
          ),
          if (reasoning != null && reasoning.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: _kIndent, top: 6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 140),
                child: SingleChildScrollView(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ReasoningPanel(
                      text: reasoning,
                      initiallyExpanded: true,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Handle, state, and — while a tool is running — the animated indicator, all
/// on one line.
class _LiveHeader extends StatelessWidget {
  const _LiveHeader({
    required this.name,
    required this.accent,
    required this.phase,
    required this.activity,
    required this.awaitingOutput,
  });

  final String name;
  final Color accent;
  final TurnPhase phase;
  final AgentToolActivity? activity;
  final bool awaitingOutput;

  @override
  Widget build(BuildContext context) {
    final current = activity;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          name,
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 8),
        // While a tool runs, the indicator already says what is happening in
        // its own words ("Leyendo lib/main.dart"), so a generic "trabajando…"
        // beside it would be noise.
        if (current != null)
          Expanded(child: AgentActivityIndicator(activity: current))
        else if (awaitingOutput)
          Flexible(
            child: Text(AppLocalizations.of(context).sessionAwaitingOutput),
          )
        else
          TurnPhaseLabel(phase: phase, accent: accent),
      ],
    );
  }
}

/// The member badge, pulsing while its turn is open. Deliberately not
/// `MemberAvatar`: that one is static by design, and a breathing border is the
/// whole point here.
class _LiveMemberAvatar extends StatefulWidget {
  const _LiveMemberAvatar({required this.accent});

  final Color accent;

  @override
  State<_LiveMemberAvatar> createState() => _LiveMemberAvatarState();
}

class _LiveMemberAvatarState extends State<_LiveMemberAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: widget.accent.withValues(
                alpha: 0.25 + 0.55 * _controller.value,
              ),
            ),
          ),
          child: child,
        );
      },
      child: Icon(Icons.smart_toy, size: 15, color: widget.accent),
    );
  }
}
