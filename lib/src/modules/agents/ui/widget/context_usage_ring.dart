import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/agents/ui/widget/context_usage_color.dart';

class ContextUsageRing extends StatelessWidget {
  const ContextUsageRing({
    super.key,
    required this.ratio,
    required this.onCompact,
  });

  final double? ratio;
  final VoidCallback onCompact;

  @override
  Widget build(BuildContext context) {
    final value = ratio;
    if (value == null) return const SizedBox.shrink();

    final color = contextUsageColor(value);
    final percent = (value * 100).round();

    return PopupMenuButton<String>(
      tooltip: 'Contexto usado: $percent%',
      onSelected: (_) => onCompact(),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'compact',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.compress, size: 18),
              const SizedBox(width: 10),
              Text('Compactar contexto ($percent%)'),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            value: value,
            strokeWidth: 2.5,
            backgroundColor: color.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ),
    );
  }
}
