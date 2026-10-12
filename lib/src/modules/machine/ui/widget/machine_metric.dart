import 'package:flutter/material.dart';

/// Una cifra con su etiqueta, un detalle al lado y, si hay [ratio], una
/// barra fina debajo.
class MachineMetric extends StatelessWidget {
  const MachineMetric({
    super.key,
    required this.label,
    required this.value,
    required this.detail,
    this.ratio,
    this.barColor,
  });

  final String label;
  final String value;
  final String detail;
  final double? ratio;

  /// El color de la barra; sin él, el del tema.
  final Color? barColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9.5,
              letterSpacing: 0.9,
              color: scheme.outline,
            ),
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: value),
                TextSpan(
                  text: '  $detail',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 17,
              letterSpacing: -0.3,
            ),
          ),
          if (ratio case final value?) ...[
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 3,
                backgroundColor: scheme.outlineVariant,
                color: barColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
