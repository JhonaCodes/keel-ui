import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/projects/model/member_color.dart';
import 'package:keel_ui/src/modules/projects/model/session_map.dart';
import 'package:keel_ui/src/modules/projects/model/session_map_layout.dart';

/// Las dos familias de línea que no salen del acento de la app: consultar y
/// delegar. Vienen de la paleta de miembros, así que el mapa sigue viviendo en
/// el mismo mundo de color que el resto.
final Color kMapConsultColor = kProjectMemberPalette[2];
final Color kMapDelegateColor = kProjectMemberPalette[1];

/// Cómo se dibuja cada evento. El grosor dice importancia, el color dice
/// familia, y el patrón dice dirección del favor: **trazo continuo avanza,
/// guiones largos piden, puntos contestan**. Con eso ida y vuelta dejan de ser
/// la misma línea.
class MapEdgeStyle {
  final Color color;
  final double width;

  /// null es trazo continuo. `(marca, hueco)` para los punteados.
  final (double, double)? dash;
  final bool arrow;

  const MapEdgeStyle({
    required this.color,
    required this.width,
    this.dash,
    this.arrow = true,
  });

  static MapEdgeStyle of(MapEdgeKind kind, ColorScheme scheme) =>
      switch (kind) {
        MapEdgeKind.forward => MapEdgeStyle(color: scheme.primary, width: 2),
        MapEdgeKind.finish => MapEdgeStyle(color: scheme.tertiary, width: 2.6),
        MapEdgeKind.failed => MapEdgeStyle(
          color: scheme.error,
          width: 2,
          dash: (5, 4),
        ),
        MapEdgeKind.back => MapEdgeStyle(
          color: kMapConsultColor,
          width: 1.8,
          dash: (8, 6),
        ),
        MapEdgeKind.answer => MapEdgeStyle(
          color: kMapConsultColor,
          width: 1.6,
          dash: (1.5, 5),
        ),
        MapEdgeKind.delegate => MapEdgeStyle(
          color: kMapDelegateColor,
          width: 1.7,
          dash: (6, 5),
        ),
        MapEdgeKind.delegateBack => MapEdgeStyle(
          color: kMapDelegateColor,
          width: 1.5,
          dash: (1.5, 5),
        ),
        MapEdgeKind.spawn => MapEdgeStyle(
          color: scheme.outline.withValues(alpha: 0.7),
          width: 1.2,
          dash: (1, 4),
          arrow: false,
        ),
        MapEdgeKind.untraveled => MapEdgeStyle(
          color: scheme.outlineVariant,
          width: 1.6,
        ),
      };
}

/// Las aristas del mapa, y solo ellas: los nodos son widgets de verdad encima
/// de esto, para que puedan tener foco, hover y texto que se abre.
class MapEdgesPainter extends CustomPainter {
  MapEdgesPainter({
    required this.map,
    required this.layout,
    required this.scheme,
    required this.progress,
  });

  final SessionMap map;
  final MapLayout layout;
  final ColorScheme scheme;

  /// 0..1 en bucle. Mueve los guiones y el punto que viaja, y NADA más: una
  /// arista que no está viva se dibuja igual con cualquier valor.
  final double progress;

  static const _gridStep = 40.0;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);
    _paintGuides(canvas, size);
    for (final edge in map.edges) {
      final path = pathOf(edge, layout);
      if (path == null) continue;
      _paintEdge(canvas, edge, path);
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = scheme.outlineVariant.withValues(alpha: 0.34);
    for (var x = _gridStep; x < size.width; x += _gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = _gridStep; y < size.height; y += _gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintGuides(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = scheme.outlineVariant.withValues(alpha: 0.9);
    for (final y in [
      MapLayout.guideTopY,
      MapLayout.guideRowY,
      if (map.nodes.any((node) => node.lane > 0)) MapLayout.guideLaneY,
    ]) {
      _strokeDashed(
        canvas,
        Path()
          ..moveTo(0, y)
          ..lineTo(size.width, y),
        paint,
        (3, 5),
        0,
      );
    }
  }

  void _paintEdge(Canvas canvas, MapEdge edge, Path path) {
    final style = MapEdgeStyle.of(edge.kind, scheme);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = style.width
      ..color = style.color;

    // Una arista en vuelo corre aunque su tipo sea de trazo continuo: el
    // movimiento es lo que dice «esto está pasando ahora», y se apaga sola en
    // cuanto el paquete llega.
    final dash = edge.live ? (style.dash ?? (7, 6)) : style.dash;
    if (dash == null) {
      canvas.drawPath(path, paint);
    } else {
      final travel = edge.live ? -progress * (dash.$1 + dash.$2) : 0.0;
      _strokeDashed(canvas, path, paint, dash, travel);
    }

    final metric = path.computeMetrics().firstOrNull;
    if (metric == null) return;
    if (style.arrow) _paintArrow(canvas, metric, style.color);
    if (edge.live) _paintPacket(canvas, metric, style.color);
  }

  void _paintArrow(Canvas canvas, PathMetric metric, Color color) {
    final tip = metric.getTangentForOffset(metric.length);
    if (tip == null) return;
    final angle = tip.angle;
    const size = 7.0;
    final path = Path()
      ..moveTo(tip.position.dx, tip.position.dy)
      ..lineTo(
        tip.position.dx - size * math.cos(angle - 0.42),
        tip.position.dy + size * math.sin(angle - 0.42),
      )
      ..lineTo(
        tip.position.dx - size * math.cos(angle + 0.42),
        tip.position.dy + size * math.sin(angle + 0.42),
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _paintPacket(Canvas canvas, PathMetric metric, Color color) {
    final at = metric.getTangentForOffset(metric.length * progress);
    if (at == null) return;
    canvas.drawCircle(
      at.position,
      3.4,
      Paint()..color = color.withValues(alpha: 0.35),
    );
    canvas.drawCircle(at.position, 2.2, Paint()..color = color);
  }

  void _strokeDashed(
    Canvas canvas,
    Path path,
    Paint paint,
    (double, double) dash,
    double offset,
  ) {
    final period = dash.$1 + dash.$2;
    for (final metric in path.computeMetrics()) {
      var start = offset % period - period;
      while (start < metric.length) {
        final end = math.min(start + dash.$1, metric.length);
        if (end > 0) {
          canvas.drawPath(metric.extractPath(math.max(start, 0), end), paint);
        }
        start += period;
      }
    }
  }

  /// El trazado de una arista. Estático porque la vista lo necesita también:
  /// el cuadro punteado de una consulta se cuelga del alto de su arco, y
  /// calcularlo dos veces con dos fórmulas es cómo se despegan.
  static Path? pathOf(MapEdge edge, MapLayout layout) {
    final from = layout.rectOf(edge.fromId);
    final to = layout.rectOf(edge.toId);
    if (from == null || to == null) return null;

    switch (edge.kind) {
      case MapEdgeKind.forward:
      case MapEdgeKind.finish:
      case MapEdgeKind.failed:
      case MapEdgeKind.untraveled:
        final y = from.center.dy;
        final leftToRight = to.left >= from.right;
        return Path()
          ..moveTo(leftToRight ? from.right + 3 : from.left - 3, y)
          ..lineTo(leftToRight ? to.left - 3 : to.right + 3, y);

      case MapEdgeKind.back:
        return _bow(from, to, MapLayout.backApexY);
      case MapEdgeKind.answer:
        return _bow(from, to, MapLayout.backApexY + 24);
      case MapEdgeKind.spawn:
        return _bow(from, to, MapLayout.spawnApexY);

      case MapEdgeKind.delegate:
        return _drop(from, to);
      case MapEdgeKind.delegateBack:
        return _drop(to, from, reversed: true);
    }
  }

  /// El arco de arriba: sube desde la cabeza de un nodo y baja a la del otro.
  static Path _bow(Rect from, Rect to, double apexY) {
    final fx = from.center.dx;
    final tx = to.center.dx;
    return Path()
      ..moveTo(fx, from.top - 3)
      ..cubicTo(fx, apexY, tx, apexY, tx, to.top - 4);
  }

  /// La caída al carril de abajo. Entra por el borde de arriba del hijo y no
  /// por su centro: una línea que termina adentro del cuadro se lee como si
  /// lo atravesara.
  static Path _drop(Rect parent, Rect child, {bool reversed = false}) {
    final px = parent.center.dx;
    final cx = child.left + 26;
    final start = Offset(px, parent.bottom + 3);
    final end = Offset(cx, child.top - 4);
    final c1 = Offset(px, parent.bottom + 58);
    final c2 = Offset(cx, child.top - 58);
    return reversed
        ? (Path()
            ..moveTo(end.dx, end.dy)
            ..cubicTo(c2.dx, c2.dy, c1.dx, c1.dy, start.dx, start.dy))
        : (Path()
            ..moveTo(start.dx, start.dy)
            ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy));
  }

  @override
  bool shouldRepaint(MapEdgesPainter old) =>
      old.progress != progress ||
      old.map != map ||
      old.layout != layout ||
      old.scheme != scheme;
}
