import 'package:flutter/material.dart';

import 'package:keel_core/modules/agents/model/effort_level.dart';

class EffortLevelSelector extends StatelessWidget {
  const EffortLevelSelector({
    super.key,
    required this.effort,
    required this.onChanged,
    this.levels = const [],
  });

  final String effort;
  final ValueChanged<String> onChanged;

  /// The levels the selected model accepts, when its provider lists them
  /// (codex). Empty: the standard levels.
  final List<String> levels;

  static IconData _iconFor(String alias) => switch (alias) {
    'low' => Icons.speed,
    'medium' => Icons.balance,
    'high' => Icons.psychology_outlined,
    'xhigh' => Icons.local_fire_department_outlined,
    'max' => Icons.local_fire_department,
    'ultra' => Icons.auto_awesome,
    _ => Icons.tune,
  };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Nivel de esfuerzo: ${effortLabel(effort)}',
      initialValue: effort,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final level
            in levels.isEmpty
                ? kEffortLevels.map((level) => level.alias)
                : levels)
          PopupMenuItem(
            value: level,
            child: Row(
              children: [
                Icon(_iconFor(level), size: 18),
                const SizedBox(width: 10),
                Text(effortLabel(level)),
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
