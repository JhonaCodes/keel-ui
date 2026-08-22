import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/projects/model/member_color.dart';
import 'package:keel_ui/src/modules/projects/model/session_graph.dart';

/// Dónde cae un nodo en el lienzo, en píxeles.
///
/// Antes era 0..1 para sobrevivir a cualquier tamaño de panel, y eso era
/// justamente el problema: con seis participantes en un panel angosto los
/// nodos se apretaban unos contra otros hasta encimarse. Ahora el lienzo
/// crece con la cantidad de nodos y el separador es fijo.
class _Placed {
  final SessionGraphNode node;
  final Offset center;

  const _Placed(this.node, this.center);
}

/// Draws the session as a network: members as nodes, workflow hand-offs as solid
/// arrows, `@handle` consults as dashed ones, and a travelling pulse on the
/// hop that is playing right now.
class SessionGraphPainter extends CustomPainter {
  SessionGraphPainter({
    required this.graph,
    required this.progress,
    required this.scheme,
    required this.textDirection,
  });

  /// 0..1 across the whole playback. Each edge owns an equal slice.
  final double progress;
  final SessionGraph graph;
  final ColorScheme scheme;
  final TextDirection textDirection;

  static const _radius = 26.0;

  /// El carril es vertical: un participante por fila, en el orden en que
  /// entró a la conversación. Los saltos se dibujan como arcos a la derecha,
  /// y los nombres a la izquierda, así ninguno de los dos pisa al otro.
  static const _rowGap = 96.0;
  static const _topPad = 64.0;
  static const _railX = 210.0;

  /// Cuánto alto necesita el mapa para [nodes] participantes sin apretarlos.
  static double heightFor(int nodes) =>
      _topPad * 2 + math.max(0, nodes - 1) * _rowGap;

  /// Which node was tapped, if any. The layout is a pure function of the
  /// canvas size, so hit-testing recomputes it rather than caching positions
  /// that a resize would silently invalidate.
  SessionGraphNode? nodeAt(Size size, Offset position) {
    for (final entry in _layout(size)) {
      if ((entry.center - position).distance <= _radius + 6) return entry.node;
    }
    return null;
  }

  static const _gridStep = 40.0;

  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = scheme.outlineVariant.withValues(alpha: 0.35);
    for (var x = _gridStep; x < size.width; x += _gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = _gridStep; y < size.height; y += _gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);
    final placed = _layout(size);
    final positions = <String, Offset>{
      for (final entry in placed) entry.node.id: entry.center,
    };
    final rowOf = <String, int>{
      for (var i = 0; i < placed.length; i++) placed[i].node.id: i,
    };
    final bows = _bows(rowOf, size);

    final edgeCount = graph.edges.length;
    final activeIndex = edgeCount == 0
        ? -1
        : (progress * edgeCount).floor().clamp(0, edgeCount - 1);
    final activeFraction = edgeCount == 0
        ? 0.0
        : (progress * edgeCount) - activeIndex;

    for (var index = 0; index < edgeCount; index++) {
      final edge = graph.edges[index];
      final from = positions[edge.fromId];
      final to = positions[edge.toId];
      if (from == null || to == null) continue;

      final drawn = switch (index.compareTo(activeIndex)) {
        < 0 => 1.0,
        0 => activeFraction,
        _ => 0.0,
      };
      _paintEdge(
        canvas: canvas,
        from: from,
        to: to,
        edge: edge,
        bow: bows[index],
        drawn: drawn,
        isActive: index == activeIndex,
        toNode: graph.nodeById(edge.toId),
      );
    }

    final reached = <String>{SessionGraphNode.userId};
    for (var index = 0; index <= activeIndex && index < edgeCount; index++) {
      reached.add(graph.edges[index].fromId);
      if (index < activeIndex || activeFraction > 0.55) {
        reached.add(graph.edges[index].toId);
      }
    }

    final workingId = activeIndex < 0 || activeIndex >= edgeCount
        ? null
        : graph.edges[activeIndex].toId;

    for (final entry in placed) {
      final isWorking = entry.node.id == workingId && activeFraction > 0.55;
      _paintNode(
        canvas: canvas,
        center: positions[entry.node.id]!,
        node: entry.node,
        touched: reached.contains(entry.node.id),
        working: isWorking,
      );

      // The caption above the working node says what it is doing right now —
      // the map should read like the thread, not like a static diagram.
      if (isWorking && activeIndex >= 0 && activeIndex < edgeCount) {
        final center = positions[entry.node.id]!;
        _paintChip(
          canvas,
          center - const Offset(0, _radius + 20),
          graph.edges[activeIndex].label,
          memberColorFor(entry.node.memberIndex),
        );
      }
    }
  }

  /// Un participante por fila, en el orden en que entró a la conversación.
  ///
  /// Antes las columnas salían de la "profundidad" de saltos, y con un
  /// workflow que vuelve al mismo agente —paso 2, 3, 5 y 8 son todos
  /// rust-expert— la profundidad de cada uno terminaba siendo la última que
  /// alcanzó: cuatro nodos apretados a la derecha, un hueco enorme en el
  /// medio y las flechas yendo para atrás. El orden de aparición no tiene ese
  /// problema porque no depende de cuántas veces vuelva a hablar cada uno.
  List<_Placed> _layout(Size size) {
    final order = <String>[SessionGraphNode.userId];
    for (final edge in graph.edges) {
      if (!order.contains(edge.fromId)) order.add(edge.fromId);
      if (!order.contains(edge.toId)) order.add(edge.toId);
    }
    for (final node in graph.nodes) {
      if (!order.contains(node.id)) order.add(node.id);
    }

    final nodes = [
      for (final id in order)
        if (graph.nodeById(id) != null) graph.nodeById(id)!,
    ];
    if (nodes.isEmpty) return const [];

    // Si el panel da más alto del mínimo, se reparte; nunca menos que el
    // separador fijo, que es lo que garantiza que no se encimen.
    final gap = nodes.length <= 1
        ? 0.0
        : math.max(_rowGap, (size.height - _topPad * 2) / (nodes.length - 1));
    final x = math.min(_railX, size.width * 0.34);

    return [
      for (var i = 0; i < nodes.length; i++)
        _Placed(nodes[i], Offset(x, _topPad + i * gap)),
    ];
  }

  /// Cuánto se arquea cada salto hacia la derecha.
  ///
  /// Proporcional a cuántas filas salta, así los arcos largos envuelven a los
  /// cortos en vez de cruzarlos; y con un escalón extra por cada repetición
  /// del MISMO par, que si no se superponen exactos y parecen uno solo.
  List<double> _bows(Map<String, int> rowOf, Size size) {
    final seen = <String, int>{};
    final room = math.max(80.0, size.width - _railX - 90);
    return [
      for (final edge in graph.edges)
        () {
          final key = '${edge.fromId}→${edge.toId}';
          final repeat = seen.update(key, (n) => n + 1, ifAbsent: () => 0);
          final rows = ((rowOf[edge.toId] ?? 0) - (rowOf[edge.fromId] ?? 0))
              .abs();
          return math.min(44.0 + rows * 30.0 + repeat * 20.0, room);
        }(),
    ];
  }

  void _paintEdge({
    required Canvas canvas,
    required Offset from,
    required Offset to,
    required SessionGraphEdge edge,
    required double bow,
    required double drawn,
    required bool isActive,
    required SessionGraphNode? toNode,
  }) {
    final dashed = edge.kind != SessionGraphEdgeKind.step;
    final color = switch (edge.kind) {
      SessionGraphEdgeKind.step => scheme.primary,
      // A consult and a creation both belong to the agent on the receiving
      // end, so they carry that member's colour rather than the workflow's.
      SessionGraphEdgeKind.consult || SessionGraphEdgeKind.spawn =>
        toNode == null ? scheme.primary : memberColorFor(toNode.memberIndex),
    };

    final path = _curve(from, to, bow: bow);
    final metric = path.computeMetrics().first;

    final rail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = scheme.outlineVariant.withValues(alpha: 0.5);
    canvas.drawPath(dashed ? _dash(metric, 1) : path, rail);

    if (drawn <= 0) return;

    final live = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = dashed ? 2 : 2.6
      ..strokeCap = StrokeCap.round
      ..color = color;
    final segment = metric.extractPath(0, metric.length * drawn);
    canvas.drawPath(
      dashed ? _dash(segment.computeMetrics().first, 1) : segment,
      live,
    );

    final tip = metric.getTangentForOffset(metric.length * drawn);
    if (tip != null) {
      _paintArrow(canvas, tip.position, tip.angle, color);
      if (isActive) {
        canvas.drawCircle(
          tip.position,
          9,
          Paint()..color = color.withValues(alpha: 0.22),
        );
      }
    }

    // Solo el salto activo lleva rótulo. Con doce saltos, doce chips sobre
    // los arcos era exactamente el amontonamiento que hacía ilegible el mapa;
    // el resto ya se lee en el panel de workflow, paso por paso.
    if (isActive && drawn > 0.35) {
      final apex = metric.getTangentForOffset(metric.length * 0.5)?.position;
      if (apex != null) _paintChip(canvas, apex, edge.label, color);
    }
  }

  /// El arco entre dos nodos del carril, siempre curvado hacia la DERECHA.
  ///
  /// Antes el arqueo salía de la normal del segmento, que en un carril
  /// vertical apunta a un lado o al otro según si el salto va hacia abajo o
  /// hacia arriba: por eso las flechas parecían irse para cualquier lado. Un
  /// punto de control corrido en +x no depende de la dirección.
  Path _curve(Offset from, Offset to, {required double bow}) {
    if (from == to) return Path()..moveTo(from.dx, from.dy);

    final control = Offset(
      math.max(from.dx, to.dx) + bow,
      (from.dy + to.dy) / 2,
    );
    final start = _pointOn(from, control, _radius + 8);
    final end = _pointOn(to, control, _radius + 12);

    return Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
  }

  Offset _pointOn(Offset origin, Offset toward, double distance) {
    final delta = toward - origin;
    final length = delta.distance;
    if (length == 0) return origin;
    return origin + delta / length * distance;
  }

  Path _dash(PathMetric metric, double scale) {
    final path = Path();
    const on = 6.0;
    const off = 5.0;
    var position = 0.0;
    while (position < metric.length) {
      final next = math.min(position + on * scale, metric.length);
      path.addPath(metric.extractPath(position, next), Offset.zero);
      position = next + off * scale;
    }
    return path;
  }

  void _paintArrow(Canvas canvas, Offset tip, double angle, Color color) {
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(-angle);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(-10, -5)
      ..lineTo(-10, 5)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  void _paintChip(Canvas canvas, Offset center, String label, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: textDirection,
    )..layout();

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: painter.width + 14,
        height: painter.height + 6,
      ),
      const Radius.circular(5),
    );
    canvas.drawRRect(rect, Paint()..color = scheme.surface);
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _paintNode({
    required Canvas canvas,
    required Offset center,
    required SessionGraphNode node,
    required bool touched,
    required bool working,
  }) {
    final color = node.isUser
        ? scheme.outline
        : memberColorFor(node.memberIndex);

    if (working) {
      canvas.drawCircle(
        center,
        _radius + 12,
        Paint()..color = color.withValues(alpha: 0.18),
      );
    }

    final box = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: _radius * 2, height: _radius * 2),
      const Radius.circular(13),
    );
    canvas.drawRRect(box, Paint()..color = scheme.surfaceContainerHighest);
    canvas.drawRRect(
      box,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = working ? 2.6 : 1.6
        ..color = touched ? color : scheme.outlineVariant,
    );

    if (node.isUser) {
      _paintText(canvas, center, 'Vos', 12, FontWeight.w600, color, null);
    } else {
      canvas.drawCircle(
        center,
        7,
        Paint()..color = touched ? color : scheme.outlineVariant,
      );
    }

    if (node.isUser) return;

    // El nombre va a la IZQUIERDA del nodo y los arcos a la derecha: debajo
    // se pisaba con el nombre del de abajo en cuanto el panel se angostaba.
    final right = center.dx - _radius - 14;
    _paintTextRight(
      canvas,
      Offset(right, center.dy - 9),
      node.label,
      12,
      FontWeight.w600,
      touched ? scheme.onSurface : scheme.outline,
      'monospace',
    );
    if (node.role.isNotEmpty) {
      _paintTextRight(
        canvas,
        Offset(right, center.dy + 9),
        node.role,
        11,
        FontWeight.normal,
        scheme.outline,
        null,
      );
    }
  }

  /// Texto pegado a [anchor] por su borde derecho, centrado verticalmente.
  void _paintTextRight(
    Canvas canvas,
    Offset anchor,
    String text,
    double size,
    FontWeight weight,
    Color color,
    String? family,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          fontWeight: weight,
          color: color,
          fontFamily: family,
        ),
      ),
      textDirection: textDirection,
      textAlign: TextAlign.right,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: math.max(40, anchor.dx - 12));
    painter.paint(
      canvas,
      Offset(anchor.dx - painter.width, anchor.dy - painter.height / 2),
    );
  }

  void _paintText(
    Canvas canvas,
    Offset center,
    String text,
    double size,
    FontWeight weight,
    Color color,
    String? family,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          fontWeight: weight,
          color: color,
          fontFamily: family,
        ),
      ),
      textDirection: textDirection,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 140);
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(SessionGraphPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.graph != graph ||
        oldDelegate.scheme != scheme;
  }
}
