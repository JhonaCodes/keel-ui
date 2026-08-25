import 'dart:math' as math;

import 'package:flutter/material.dart';

/// El cuadro punteado del mapa: un encabezado corto de color y dos o tres
/// líneas de texto.
///
/// Chico a propósito. Es un rótulo puesto encima del recorrido, no una
/// tarjeta: tiene que decir de qué se habló y dejar ver el mapa. Lo entero se
/// lee tocándolo.
///
/// Uno solo para los tres que hay —lo que resolvió un nodo, lo que se
/// preguntaron dos, lo que devolvió un subagente— porque son el mismo objeto
/// con distinto color. Tres copias con el mismo dibujo es cómo se separan sin
/// que nadie lo decida.
class MapCalloutBox extends StatelessWidget {
  const MapCalloutBox({
    super.key,
    required this.icon,
    required this.label,
    required this.text,
    required this.color,
    this.onTap,
    this.maxLines = 3,
    this.opaque = false,
    this.reasoning,
  });

  final IconData icon;
  final String label;
  final String text;
  final Color color;
  final VoidCallback? onTap;
  final int maxLines;

  /// Con fondo propio, para el que se dibuja encima de un arco: sin él, la
  /// línea pasa por detrás del texto y ninguno de los dos se lee.
  final bool opaque;

  /// El razonamiento plegado, cuando este cuadro lo lleva. Se dibuja abajo del
  /// texto con un divisor punteado —el `.think-peek` del mockup—.
  final String? reasoning;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final box = CustomPaint(
      painter: MapDashedBoxPainter(
        color: color,
        fill: opaque ? scheme.surface.withValues(alpha: 0.97) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(9, 6, 9, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 11, color: color),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      height: 1.1,
                      letterSpacing: 1,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              text,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.3,
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (reasoning case final peek?) ...[
              const SizedBox(height: 5),
              SizedBox(
                height: 1,
                child: CustomPaint(
                  painter: _DashedRulePainter(
                    color: scheme.outline.withValues(alpha: 0.55),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.chevron_right, size: 10, color: scheme.outline),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      peek,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        height: 1.3,
                        color: scheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return box;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: box),
    );
  }
}

class MapDashedBoxPainter extends CustomPainter {
  const MapDashedBoxPainter({required this.color, this.fill});

  final Color color;
  final Color? fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(7),
    );
    if (fill case final background?) {
      canvas.drawRRect(rrect, Paint()..color = background);
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      var start = 0.0;
      while (start < metric.length) {
        canvas.drawPath(
          metric.extractPath(start, math.min(start + 3.5, metric.length)),
          paint,
        );
        start += 6.5;
      }
    }
  }

  @override
  bool shouldRepaint(MapDashedBoxPainter old) =>
      old.color != color || old.fill != fill;
}

/// El divisor punteado del `.think-peek`: una línea de guiones de 3 puntos
/// con 3 de hueco, como el `border-top: 1px dashed` del mockup.
class _DashedRulePainter extends CustomPainter {
  const _DashedRulePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1
      ..color = color;
    const dash = 3.0;
    const gap = 3.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, 0.5),
        Offset(math.min(x + dash, size.width), 0.5),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedRulePainter old) => old.color != color;
}
