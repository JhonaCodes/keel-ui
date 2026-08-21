import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/stations/model/member_color.dart';
import 'package:keel_ui/src/modules/stations/model/task_graph.dart';

/// Where a node sits on the canvas, in normalized 0..1 space so the layout
/// survives any panel size.
class _Placed {
  final TaskGraphNode node;
  final Offset unit;

  const _Placed(this.node, this.unit);
}

/// Draws the task as a network: members as nodes, workflow hand-offs as solid
/// arrows, `@handle` consults as dashed ones, and a travelling pulse on the
/// hop that is playing right now.
class StationGraphPainter extends CustomPainter {
  StationGraphPainter({
    required this.graph,
    required this.progress,
    required this.scheme,
    required this.textDirection,
  });

  /// 0..1 across the whole playback. Each edge owns an equal slice.
  final double progress;
  final TaskGraph graph;
  final ColorScheme scheme;
  final TextDirection textDirection;

  static const _radius = 26.0;

  /// Which node was tapped, if any. The layout is a pure function of the
  /// canvas size, so hit-testing recomputes it rather than caching positions
  /// that a resize would silently invalidate.
  TaskGraphNode? nodeAt(Size size, Offset position) {
    for (final entry in _layout(size)) {
      final center = Offset(
        entry.unit.dx * size.width,
        entry.unit.dy * size.height,
      );
      if ((center - position).distance <= _radius + 6) return entry.node;
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
      for (final entry in placed)
        entry.node.id: Offset(
          entry.unit.dx * size.width,
          entry.unit.dy * size.height,
        ),
    };

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
        drawn: drawn,
        isActive: index == activeIndex,
        toNode: graph.nodeById(edge.toId),
      );
    }

    final reached = <String>{TaskGraphNode.userId};
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

  /// Origin on the left, then one column per hand-off depth, so the flow reads
  /// left to right. Consult-only members are pushed to the lower band.
  List<_Placed> _layout(Size size) {
    final depth = <String, int>{TaskGraphNode.userId: 0};
    for (final edge in graph.edges) {
      final base = depth[edge.fromId] ?? 0;
      // A consult answers in place; a hand-off and a newly created agent both
      // move the flow one column to the right.
      final next = edge.kind == TaskGraphEdgeKind.consult ? base : base + 1;
      depth[edge.toId] = math.max(depth[edge.toId] ?? 0, next);
    }

    final byDepth = <int, List<TaskGraphNode>>{};
    for (final node in graph.nodes) {
      if (!depth.containsKey(node.id) && !node.isUser) continue;
      byDepth.putIfAbsent(depth[node.id] ?? 0, () => []).add(node);
    }

    final maxDepth = byDepth.keys.fold<int>(0, math.max);
    final placed = <_Placed>[];
    for (final entry in byDepth.entries) {
      final column = entry.value;
      final x = maxDepth == 0 ? 0.5 : 0.10 + (entry.key / maxDepth) * 0.80;
      for (var row = 0; row < column.length; row++) {
        final y = column.length == 1
            ? 0.42
            : 0.20 + (row / (column.length - 1)) * 0.58;
        placed.add(_Placed(column[row], Offset(x, y)));
      }
    }
    return placed;
  }

  void _paintEdge({
    required Canvas canvas,
    required Offset from,
    required Offset to,
    required TaskGraphEdge edge,
    required double drawn,
    required bool isActive,
    required TaskGraphNode? toNode,
  }) {
    final dashed = edge.kind != TaskGraphEdgeKind.step;
    final color = switch (edge.kind) {
      TaskGraphEdgeKind.step => scheme.primary,
      // A consult and a creation both belong to the agent on the receiving
      // end, so they carry that member's colour rather than the workflow's.
      TaskGraphEdgeKind.consult || TaskGraphEdgeKind.spawn =>
        toNode == null ? scheme.primary : memberColorFor(toNode.memberIndex),
    };

    final bow = switch (edge.kind) {
      TaskGraphEdgeKind.step => -26.0,
      TaskGraphEdgeKind.consult => 46.0,
      // Bowed the other way so a created agent never overlaps a consult drawn
      // between the same two members.
      TaskGraphEdgeKind.spawn => -58.0,
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

    if (drawn > 0.5) {
      final mid = metric.getTangentForOffset(metric.length * 0.5)?.position;
      if (mid != null) {
        _paintChip(canvas, mid, edge.label, isActive ? color : scheme.outline);
      }
    }
  }

  Path _curve(Offset from, Offset to, {required double bow}) {
    final delta = to - from;
    final length = delta.distance;
    if (length == 0) return Path()..moveTo(from.dx, from.dy);

    final normal = Offset(-delta.dy / length, delta.dx / length) * bow;
    final mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2) + normal;

    final start = from + (_pointOn(from, mid, _radius + 8) - from);
    final end = to + (_pointOn(to, mid, _radius + 12) - to);

    return Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy);
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
    required TaskGraphNode node,
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

    _paintText(
      canvas,
      center + Offset(0, _radius + 18),
      node.label,
      12,
      FontWeight.w600,
      touched ? scheme.onSurface : scheme.outline,
      'monospace',
    );
    if (node.role.isNotEmpty) {
      _paintText(
        canvas,
        center + Offset(0, _radius + 34),
        node.role,
        11,
        FontWeight.normal,
        scheme.outline,
        null,
      );
    }
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
  bool shouldRepaint(StationGraphPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.graph != graph ||
        oldDelegate.scheme != scheme;
  }
}
