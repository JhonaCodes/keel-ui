import 'dart:math';

import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/agents/model/agent_tool_activity.dart';

enum _ToolAnimationStyle { spin, pulse, bounce }

class AgentActivityIndicator extends StatefulWidget {
  const AgentActivityIndicator({super.key, required this.activity});

  final AgentToolActivity? activity;

  @override
  State<AgentActivityIndicator> createState() => _AgentActivityIndicatorState();
}

class _AgentActivityIndicatorState extends State<AgentActivityIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static IconData _iconFor(AgentToolKind kind) => switch (kind) {
    AgentToolKind.bash => Icons.terminal,
    AgentToolKind.read => Icons.visibility_outlined,
    AgentToolKind.write => Icons.edit_note,
    AgentToolKind.edit => Icons.edit_outlined,
    AgentToolKind.multiEdit => Icons.edit_document,
    AgentToolKind.grep => Icons.manage_search,
    AgentToolKind.glob => Icons.folder_open,
    AgentToolKind.webFetch => Icons.public,
    AgentToolKind.webSearch => Icons.travel_explore,
    AgentToolKind.task => Icons.hub_outlined,
    AgentToolKind.todoWrite => Icons.checklist,
    AgentToolKind.notebookEdit => Icons.menu_book_outlined,
    AgentToolKind.bashOutput => Icons.subject,
    AgentToolKind.killShell => Icons.stop_circle_outlined,
    AgentToolKind.exitPlanMode => Icons.map_outlined,
    AgentToolKind.other => Icons.bolt_outlined,
  };

  static _ToolAnimationStyle _styleFor(AgentToolKind kind) => switch (kind) {
    AgentToolKind.webSearch ||
    AgentToolKind.webFetch ||
    AgentToolKind.task => _ToolAnimationStyle.spin,
    AgentToolKind.write ||
    AgentToolKind.edit ||
    AgentToolKind.multiEdit ||
    AgentToolKind.notebookEdit ||
    AgentToolKind.todoWrite => _ToolAnimationStyle.pulse,
    _ => _ToolAnimationStyle.bounce,
  };

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    if (activity == null) return const SizedBox.shrink();

    final icon = _iconFor(activity.kind);
    final style = _styleFor(activity.kind);
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            return switch (style) {
              _ToolAnimationStyle.spin => Transform.rotate(
                angle: t * 2 * pi,
                child: child,
              ),
              _ToolAnimationStyle.pulse => Transform.scale(
                scale: 0.85 + 0.25 * (0.5 + 0.5 * sin(t * 2 * pi)),
                child: child,
              ),
              _ToolAnimationStyle.bounce => Transform.translate(
                offset: Offset(0, -3 * sin(t * 2 * pi)),
                child: child,
              ),
            };
          },
          child: Icon(icon, size: 14, color: scheme.primary),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            activity.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
