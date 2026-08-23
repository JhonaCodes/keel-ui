import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/projects/model/session_map.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/map_edges_painter.dart';

/// Qué significa cada línea.
///
/// Es un botón, no un cartel fijo: la regla —**trazo continuo avanza,
/// guiones largos piden, puntos contestan**— se aprende una vez, y después
/// una leyenda permanente solo come lienzo.
class MapLegend extends StatelessWidget {
  const MapLegend({super.key, required this.onClose});

  final VoidCallback onClose;

  static const _entries = <(MapEdgeKind, String)>[
    (MapEdgeKind.forward, 'avanza un paso'),
    (MapEdgeKind.back, 'consulta a otro nodo'),
    (MapEdgeKind.answer, 'contesta esa consulta'),
    (MapEdgeKind.delegate, 'abre un subagente'),
    (MapEdgeKind.delegateBack, 'el subagente devolvió'),
    (MapEdgeKind.spawn, 'lo registró'),
    (MapEdgeKind.finish, 'entrega final'),
    (MapEdgeKind.failed, 'cortó'),
    (MapEdgeKind.untraveled, 'sin recorrer'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 254,
      padding: const EdgeInsets.fromLTRB(14, 11, 12, 13),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'LEYENDA',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  letterSpacing: 1.3,
                  color: scheme.outline,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: onClose,
                child: Icon(Icons.close, size: 14, color: scheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final (kind, label) in _entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 46,
                    height: 12,
                    child: CustomPaint(
                      painter: _SwatchPainter(
                        style: MapEdgeStyle.of(kind, scheme),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SwatchPainter extends CustomPainter {
  const _SwatchPainter({required this.style});

  final MapEdgeStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = style.width
      ..color = style.color;

    final y = size.height / 2;
    final end = style.arrow ? size.width - 6 : size.width;
    final dash = style.dash;
    if (dash == null) {
      canvas.drawLine(Offset(0, y), Offset(end, y), paint);
    } else {
      var x = 0.0;
      while (x < end) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + dash.$1, end), y),
          paint,
        );
        x += dash.$1 + dash.$2;
      }
    }

    if (!style.arrow) return;
    canvas.drawPath(
      Path()
        ..moveTo(size.width, y)
        ..lineTo(size.width - 7, y - 3.4)
        ..lineTo(size.width - 7, y + 3.4)
        ..close(),
      Paint()..color = style.color,
    );
  }

  @override
  bool shouldRepaint(_SwatchPainter old) => old.style != style;
}
