import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/agents/ui/widget/context_usage_color.dart';

class AgentStatusIcon extends StatefulWidget {
  const AgentStatusIcon({
    super.key,
    required this.color,
    required this.selected,
    required this.isWorking,
    this.contextRatio,
  });

  final Color color;
  final bool selected;
  final bool isWorking;
  final double? contextRatio;

  @override
  State<AgentStatusIcon> createState() => _AgentStatusIconState();
}

class _AgentStatusIconState extends State<AgentStatusIcon>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(AgentStatusIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isWorking != widget.isWorking) _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.isWorking) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 1 - (_controller.value * 0.6),
          child: Icon(
            widget.selected ? Icons.smart_toy : Icons.smart_toy_outlined,
            color: widget.color,
          ),
        );
      },
    );

    final ratio = widget.contextRatio;
    if (widget.selected || ratio == null) return icon;

    final color = contextUsageColor(ratio);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(height: 2),
        SizedBox(
          width: 20,
          height: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 3,
              backgroundColor: color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}
