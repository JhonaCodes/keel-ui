import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/agents/model/effort_level.dart';

class EffortLevelSelector extends StatelessWidget {
  const EffortLevelSelector({
    super.key,
    required this.effort,
    required this.onChanged,
  });

  final String effort;
  final ValueChanged<String> onChanged;

  static IconData _iconFor(String alias) => switch (alias) {
    'low' => Icons.speed,
    'medium' => Icons.balance,
    'high' => Icons.psychology_outlined,
    'xhigh' => Icons.local_fire_department_outlined,
    'max' => Icons.local_fire_department,
    _ => Icons.tune,
  };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Nivel de esfuerzo: ${effortLabel(effort)}',
      initialValue: effort,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final level in kEffortLevels)
          PopupMenuItem(
            value: level.alias,
            child: Row(
              children: [
                Icon(_iconFor(level.alias), size: 18),
                const SizedBox(width: 10),
                Text(level.label),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconFor(effort), size: 18),
            const SizedBox(width: 4),
            Text(
              effortLabel(effort),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}
