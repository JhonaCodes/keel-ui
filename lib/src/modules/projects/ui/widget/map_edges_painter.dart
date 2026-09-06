import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/modules/projects/model/member_color.dart';
import 'package:keel_ui/src/modules/projects/model/session_map.dart';
import 'package:keel_ui/src/modules/projects/model/session_map_layout.dart';

/// Las dos familias de línea que no salen del acento de la app: consultar y
/// delegar. Vienen de la paleta de miembros, así que el mapa sigue viviendo en
/// el mismo mundo de color que el resto.
final Color kMapConsultColor = kProjectMemberPalette[2];
final Color kMapDelegateColor = kProjectMemberPalette[1];

/// La línea «sin recorrer»: tiene color propio, más presente que el `rule` que
/// es `scheme.outlineVariant`. Este gris reemplaza al azul del mockup viejo
/// conservando su luminancia — contra el fondo daba 2.02:1 y ahora da 2.00:1,
/// así que se ve igual de presente sin ser la única isla azul de la app.
const Color kMapIdleEdgeColor = Color(0xFF4A4A4A);

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
          color: scheme.outline,
          width: 1.2,
          dash: (1, 4),
          arrow: false,
        ),
        MapEdgeKind.untraveled => MapEdgeStyle(
          color: kMapIdleEdgeColor,
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

  /// Las que se apagan cuando ya pasaron. Una consulta cerrada al 45 % deja
  /// el recorrido de avance como lo primero que se ve; a full compite con él
  /// y con las demás, que es lo que hacía que el lienzo se leyera como una
  /// maraña.
  static const _fades = {
    MapEdgeKind.back,
    MapEdgeKind.answer,
    MapEdgeKind.delegateBack,
  };

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);
    _paintGuides(canvas, size);
    // Lo cerrado primero y lo vivo después: lo que está pasando ahora se
    // dibuja encima de lo que ya pasó, no debajo.
    for (final edge in map.edges.where((edge) => !edge.live)) {
      final path = layout.routeOf(edge);
      if (path != null) _paintEdge(canvas, edge, path);
    }
    for (final edge in map.edges.where((edge) => edge.live)) {
      final path = layout.routeOf(edge);
      if (path != null) _paintEdge(canvas, edge, path);
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = scheme.outlineVariant.withValues(alpha: 0.55);
    // Desde 0 y no desde el paso: la primera línea del borde también existe
    // en el mockup —su `.grid` arranca en `inset: 0`—.
    for (var x = 0.0; x < size.width; x += _gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += _gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintGuides(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = scheme.outlineVariant.withValues(alpha: 0.9);
    for (final y in [
      layout.guideTopY,
      layout.guideRowY,
      if (map.nodes.any((node) => node.lane > 0)) layout.guideLaneY,
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
    final style = _styleOf(edge);
    final color = _fades.contains(edge.kind) && !edge.live
        ? style.color.withValues(alpha: 0.45)
        : style.color;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      // Los caminos son quebrados: sin esto las esquinas cierran en punta.
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = style.width
      ..color = color;

    // Una arista en vuelo corre aunque su tipo sea de trazo continuo: el
    // movimiento es lo que dice «esto está pasando ahora», y se apaga sola en
    // cuanto el paquete llega.
    final dash = edge.live ? (style.dash ?? (7, 6)) : style.dash;
    if (dash == null) {
      canvas.drawPath(path, paint);
    } else {
      // Dos períodos por vuelta: el dibujo aprobado mueve 28 puntos por
      // segundo y a un período por ciclo esto iba a la mitad.
      final travel = edge.live ? -progress * (dash.$1 + dash.$2) * 2 : 0.0;
      _strokeDashed(canvas, path, paint, dash, travel);
    }

    final metric = path.computeMetrics().firstOrNull;
    if (metric == null) return;
    if (style.arrow) _paintArrow(canvas, metric, color);
    if (edge.live) _paintPacket(canvas, metric, color);
  }

  /// El estilo efectivo de una arista. La única que cambia según el estado
  /// del destino es el avance: cuando el paquete llegó y el destino está
  /// procesando, se atenúa a brass-deep (`.e-fwd.q` del mockup) en vez de
  /// quedarse en el brass del avance recorrido.
  MapEdgeStyle _styleOf(MapEdge edge) {
    if (_forwardIsResting(edge)) {
      return MapEdgeStyle(color: AppColors.brassDeep, width: 1.6);
    }
    return MapEdgeStyle.of(edge.kind, scheme);
  }

  bool _forwardIsResting(MapEdge edge) {
    if (edge.kind != MapEdgeKind.forward || edge.live) return false;
    return switch (map.nodeById(edge.toId)?.state) {
      MapNodeState.thinking ||
      MapNodeState.working ||
      MapNodeState.writing => true,
      _ => false,
    };
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

  @override
  bool shouldRepaint(MapEdgesPainter old) =>
      old.progress != progress ||
      old.map != map ||
      old.layout != layout ||
      old.scheme != scheme;
}
