import 'dart:math' as math;
import 'dart:ui';

import 'package:keel_ui/src/modules/projects/model/session_map.dart';

/// Dónde cae cada nodo en el lienzo, y por dónde va cada línea.
///
/// Es geometría pura y determinista: la misma sesión da siempre el mismo
/// dibujo. Los nodos NO se pueden arrastrar a propósito — una disposición que
/// el usuario puede desordenar es una que hay que guardar, migrar y arreglar
/// cuando queda rara, y lo que se gana es nada.
///
/// El trazado de las aristas vive acá y no en el pintor porque depende de la
/// distribución: qué corredor le tocó a cada par y por qué punto del borde
/// sale. Calcularlo en el pintor era lo que hacía que todas las réplicas
/// usaran la misma altura y se cruzaran entre ellas.
class MapLayout {
  /// La caja del nodo que usan las aristas. Lo que cuelgue abajo —el cuadro
  /// punteado de «resolvió»— crece fuera de esta caja: las líneas apuntan a la
  /// cabeza del nodo, no a su texto.
  static const nodeWidth = 148.0;
  static const smallWidth = 96.0;
  static const nodeHeight = 70.0;

  /// El cuadro de «resolvió» es MÁS ancho que el nodo, y se pasa hacia la
  /// derecha. Al ancho del nodo, dos palabras entran por línea y la frase se
  /// corta antes de decir nada.
  static const resolutionWidth = 196.0;

  /// El cuadro de una réplica, arriba. Más ancho que el nodo y que su
  /// columna: el encabezado lleva los dos handles y una flecha.
  static const calloutWidth = 240.0;
  static const calloutHeight = 62.0;

  /// Lo que tiene que sobrar entre dos cosas de la misma fila para que no se
  /// lean como una sola.
  static const _rowSlack = 16.0;

  /// Entre la línea de ida y la de vuelta del mismo par: dos rieles
  /// paralelos, no una encima de la otra.
  static const corridorGap = 9.0;

  /// El radio de las esquinas de un camino recto. Recto, pero no de circuito
  /// impreso.
  static const corridorRadius = 10.0;

  /// Aire entre columnas. Ancho porque el cuadro de «resolvió» mide 196 y a
  /// 56 quedaban 8 puntos entre cuadro y cuadro: seis pasos seguidos se leían
  /// como una tira continua en vez de seis cosas.
  static const columnGap = 76.0;
  static const padLeft = 28.0;
  static const padRight = 56.0;

  /// Cuánto aire hay antes del primer carril.
  static const _topPad = 54.0;

  /// El alto mínimo de la banda de «vuelve», sin ningún cuadro adentro.
  static const _minTopBand = 74.0;

  /// Lo que ocupa una fila de réplicas: su cuadro, el aire hasta el corredor,
  /// los dos rieles y el respiro hasta la fila siguiente.
  static const _rowPitch = calloutHeight + 12 + corridorGap + 30;

  /// Del carril de avanzar al de delegar, y del de delegar a los subagentes.
  static const _rowToGuideLane = 162.0;
  static const _rowToLane = 186.0;

  /// Alto del nodo MÁS su cuadro punteado: con el paso justo, el subagente
  /// de abajo tapaba lo que devolvió el de arriba.
  static const laneSlotPitch = 150.0;
  static const bottomPad = 44.0;

  final Size size;
  final Map<String, Rect> _rects;
  final List<MapNode> nodes;

  /// Dónde va el cuadro de cada réplica, por [MapCallout.pairId].
  final Map<String, Rect> calloutRects;

  /// A qué altura corre el corredor de cada par, por [MapCallout.pairId].
  final Map<String, double> _corridors;

  /// Por qué punto del borde de arriba sale cada arista, por `'$edgeKey@$nodeId'`.
  final Map<String, double> _ports;

  /// Los tres carriles: arriba vuelve, al medio avanza, abajo se delega.
  /// Son siempre los mismos y en el mismo orden, así que una línea que sube
  /// significa lo mismo en cualquier sesión sin mirar la leyenda. Sus alturas
  /// dependen de cuántas filas de réplicas haya arriba.
  final double guideTopY;
  final double guideRowY;
  final double rowY;
  final double guideLaneY;
  final double laneY;

  const MapLayout._({
    required this.size,
    required this._rects,
    required this.nodes,
    required this.calloutRects,
    required this._corridors,
    required this._ports,
    required this.guideTopY,
    required this.guideRowY,
    required this.rowY,
    required this.guideLaneY,
    required this.laneY,
  });

  /// El corredor de «lo registró», arriba de todas las réplicas: es una
  /// relación de elenco y no tiene que cruzarse con lo que está pasando.
  double get spawnCorridorY => guideTopY + 16;

  Rect? rectOf(String id) => _rects[id];

  /// El nodo que cae bajo un punto del lienzo, si hay alguno.
  MapNode? nodeAt(Offset point) {
    for (final node in nodes) {
      if (_rects[node.id]?.contains(point) ?? false) return node;
    }
    return null;
  }

  /// La caja que ocupa todo lo dibujado, cuadros colgantes incluidos. Es lo
  /// que hay que encuadrar: el lienzo tiene aire alrededor a propósito, y
  /// encuadrar el aire deja el mapa chiquito en el medio de la nada.
  Rect get contentBounds {
    var bounds = Rect.zero;
    for (final rect in [..._rects.values, ...calloutRects.values]) {
      bounds = bounds == Rect.zero ? rect : bounds.expandToInclude(rect);
    }
    if (bounds == Rect.zero) return Offset.zero & size;
    // Lo que cuelga de un nodo cerrado no está en `_rects`: se suma acá.
    return Rect.fromLTRB(
      bounds.left - 12,
      bounds.top - 12,
      math.max(bounds.right, bounds.left + resolutionWidth) + 12,
      bounds.bottom + 96,
    ).intersect(Offset.zero & size);
  }

  /// El camino de una arista, ya ruteado.
  ///
  /// Las que van de un paso al siguiente son rectas horizontales; las que
  /// suben o bajan son **ortogonales**: salen derecho del borde, corren por
  /// su corredor y entran derecho al otro. Un arco por par era legible con
  /// una consulta y una maraña con dos.
  Path? routeOf(MapEdge edge) {
    final from = _rects[edge.fromId];
    final to = _rects[edge.toId];
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
        return _overpass(edge, from, to, _corridorOf(edge));
      case MapEdgeKind.answer:
        return _overpass(edge, from, to, _corridorOf(edge) + corridorGap);
      case MapEdgeKind.spawn:
        return _overpass(edge, from, to, spawnCorridorY);

      case MapEdgeKind.delegate:
        return _underpass(edge, from, to);
      case MapEdgeKind.delegateBack:
        return _underpass(edge, from, to, reversed: true);
    }
  }

  double _corridorOf(MapEdge edge) {
    final ends = [edge.fromId, edge.toId]..sort();
    return _corridors[ends.join('>')] ?? guideRowY - 34;
  }

  double _portOf(MapEdge edge, String nodeId, Rect rect) =>
      _ports['${_edgeKey(edge)}@$nodeId'] ?? rect.center.dx;

  static String _edgeKey(MapEdge edge) =>
      '${edge.fromId}>${edge.toId}>${edge.kind.name}';

  /// Sube del borde de arriba de un nodo, corre por [corridorY] y baja al
  /// otro. Las esquinas son arcos: recto no quiere decir filoso.
  Path _overpass(MapEdge edge, Rect from, Rect to, double corridorY) {
    final startX = _portOf(edge, edge.fromId, from);
    final endX = _portOf(edge, edge.toId, to);
    return _elbow(
      start: Offset(startX, from.top - 3),
      end: Offset(endX, to.top - 4),
      corridorY: corridorY,
    );
  }

  /// La bajada al carril de los subagentes: baja del pie del padre, dobla a
  /// un montante a la izquierda de la columna y entra a cada hijo por su
  /// costado. Es un árbol, y se dibuja como un árbol.
  ///
  /// El montante existe porque los subagentes de un mismo padre se apilan en
  /// la misma columna: una línea que bajara derecho hasta el tercero
  /// atravesaría los cuadros de los dos primeros.
  Path _underpass(MapEdge edge, Rect from, Rect to, {bool reversed = false}) {
    final parent = reversed ? to : from;
    final child = reversed ? from : to;
    // Dos montantes de a diez puntos: el de ida y el de vuelta, como los dos
    // rieles de una consulta allá arriba.
    final riser = child.left - (reversed ? 12 : 22);
    final shelf = parent.bottom + 16;
    final entry = Offset(child.left - 4, child.center.dy);
    final exit = Offset(parent.center.dx, parent.bottom + 3);

    Path draw() => Path()
      ..moveTo(exit.dx, exit.dy)
      ..lineTo(exit.dx, shelf - corridorRadius)
      ..arcToPoint(
        Offset(exit.dx - corridorRadius, shelf),
        radius: const Radius.circular(corridorRadius),
        clockwise: false,
      )
      ..lineTo(riser + corridorRadius, shelf)
      ..arcToPoint(
        Offset(riser, shelf + corridorRadius),
        radius: const Radius.circular(corridorRadius),
        clockwise: false,
      )
      ..lineTo(riser, entry.dy - corridorRadius)
      ..arcToPoint(
        Offset(riser + corridorRadius, entry.dy),
        radius: const Radius.circular(corridorRadius),
        clockwise: true,
      )
      ..lineTo(entry.dx, entry.dy);

    if (!reversed) return draw();
    // La devolución es el mismo recorrido al revés: que las dos coincidan de
    // forma es lo que las hace leer como ida y vuelta de lo mismo.
    return _reverse(draw());
  }

  /// Un camino recorrido para el otro lado, punto por punto.
  static Path _reverse(Path path) {
    final metric = path.computeMetrics().first;
    final reversed = Path();
    const steps = 48;
    for (var i = steps; i >= 0; i--) {
      final point = metric.getTangentForOffset(metric.length * i / steps)!;
      if (i == steps) {
        reversed.moveTo(point.position.dx, point.position.dy);
      } else {
        reversed.lineTo(point.position.dx, point.position.dy);
      }
    }
    return reversed;
  }

  /// El camino de tres tramos: vertical, horizontal, vertical.
  static Path _elbow({
    required Offset start,
    required Offset end,
    required double corridorY,
  }) {
    final path = Path()..moveTo(start.dx, start.dy);
    final span = (end.dx - start.dx).abs();
    // Sin lugar para dos esquinas, una recta hace menos ruido que dos arcos
    // pegados que se comen entre sí.
    if (span < corridorRadius * 2.4) {
      return path
        ..lineTo(start.dx, corridorY)
        ..lineTo(end.dx, corridorY)
        ..lineTo(end.dx, end.dy);
    }

    final toTheRight = end.dx > start.dx;
    final radius = math.min(
      corridorRadius,
      math.min(
        span / 2,
        math.min((start.dy - corridorY).abs(), (end.dy - corridorY).abs()),
      ),
    );
    final step = toTheRight ? radius : -radius;
    final upFromStart = start.dy > corridorY;
    final downToEnd = end.dy > corridorY;

    return path
      ..lineTo(start.dx, corridorY + (upFromStart ? radius : -radius))
      ..arcToPoint(
        Offset(start.dx + step, corridorY),
        radius: const Radius.circular(corridorRadius),
        clockwise: upFromStart == toTheRight,
      )
      ..lineTo(end.dx - step, corridorY)
      ..arcToPoint(
        Offset(end.dx, corridorY + (downToEnd ? radius : -radius)),
        radius: const Radius.circular(corridorRadius),
        clockwise: downToEnd != toTheRight,
      )
      ..lineTo(end.dx, end.dy);
  }

  factory MapLayout.of(SessionMap map) {
    final columnWidth = <int, double>{};
    for (final node in map.nodes) {
      final width = _widthOf(node);
      final current = columnWidth[node.column] ?? 0;
      if (width > current) columnWidth[node.column] = width;
    }

    final columnX = <int, double>{};
    var x = padLeft;
    for (var column = 0; column < map.columns; column++) {
      columnX[column] = x;
      x += (columnWidth[column] ?? nodeWidth) + columnGap;
    }
    final width = x - columnGap + padRight;

    double? centerOf(String nodeId) {
      final node = map.nodeById(nodeId);
      if (node == null) return null;
      final left = columnX[node.column];
      if (left == null) return null;
      return left + _widthOf(node) / 2;
    }

    // ── una fila por par, y las que no se cruzan la comparten ────────────
    //
    // El tramo que se mide es el de la LÍNEA unido al del cuadro, no solo el
    // del cuadro: dos réplicas cuyos cuadros no se tocan igual cruzaban sus
    // líneas, que es la maraña que había que sacar.
    final spans = <String, ({double left, double right, double calloutLeft})>{};
    for (final callout in map.callouts) {
      final from = centerOf(callout.fromId);
      final to = centerOf(callout.toId);
      if (from == null || to == null) continue;
      final calloutLeft = ((from + to) / 2 - calloutWidth / 2).clamp(
        padLeft,
        math.max(padLeft, width - padRight - calloutWidth),
      );
      spans[callout.pairId] = (
        left: math.min(math.min(from, to), calloutLeft.toDouble()),
        right: math.max(
          math.max(from, to),
          calloutLeft.toDouble() + calloutWidth,
        ),
        calloutLeft: calloutLeft.toDouble(),
      );
    }

    final rowOf = <String, int>{};
    final rowEnds = <double>[];
    final ordered = spans.entries.toList()
      ..sort((a, b) => a.value.left.compareTo(b.value.left));
    for (final entry in ordered) {
      var row = 0;
      while (row < rowEnds.length &&
          entry.value.left < rowEnds[row] + _rowSlack) {
        row++;
      }
      if (row == rowEnds.length) rowEnds.add(0);
      rowEnds[row] = entry.value.right;
      rowOf[entry.key] = row;
    }

    final rows = rowEnds.length;
    const guideTopY = _topPad;
    final band = rows == 0
        ? _minTopBand
        : math.max(_minTopBand, 14 + rows * _rowPitch + 8);
    final guideRowY = guideTopY + band;
    final rowY = guideRowY + 26;
    final guideLaneY = rowY + _rowToGuideLane;
    final laneY = rowY + _rowToLane;

    final calloutRects = <String, Rect>{};
    final corridors = <String, double>{};
    for (final entry in rowOf.entries) {
      final top = guideTopY + 14 + entry.value * _rowPitch;
      calloutRects[entry.key] = Rect.fromLTWH(
        spans[entry.key]!.calloutLeft,
        top,
        calloutWidth,
        calloutHeight,
      );
      corridors[entry.key] = top + calloutHeight + 12;
    }

    final rects = <String, Rect>{};
    var deepestSlot = 0;
    for (final node in map.nodes) {
      final left = columnX[node.column] ?? padLeft;
      final top = node.lane == 0 ? rowY : laneY + node.laneSlot * laneSlotPitch;
      if (node.lane > 0 && node.laneSlot > deepestSlot) {
        deepestSlot = node.laneSlot;
      }
      rects[node.id] = Rect.fromLTWH(left, top, _widthOf(node), nodeHeight);
    }

    final hasLane = map.nodes.any((node) => node.lane > 0);
    final height = hasLane
        ? laneY + (deepestSlot + 1) * laneSlotPitch + bottomPad
        : rowY + nodeHeight + 130;

    return MapLayout._(
      size: Size(width, height),
      rects: rects,
      nodes: map.nodes,
      calloutRects: calloutRects,
      corridors: corridors,
      ports: _portsOf(map, rects),
      guideTopY: guideTopY,
      guideRowY: guideRowY,
      rowY: rowY,
      guideLaneY: guideLaneY,
      laneY: laneY,
    );
  }

  /// Por dónde sale cada línea del borde de arriba de cada nodo.
  ///
  /// Repartidas y no todas por el centro: dos consultas que tocan el mismo
  /// nodo salían del mismo punto y se superponían desde el arranque. Se
  /// ordenan por hacia dónde va el otro extremo, así tampoco se cruzan al
  /// salir.
  static Map<String, double> _portsOf(SessionMap map, Map<String, Rect> rects) {
    const upward = {MapEdgeKind.back, MapEdgeKind.answer, MapEdgeKind.spawn};
    final byNode = <String, List<(MapEdge, String)>>{};
    for (final edge in map.edges) {
      if (!upward.contains(edge.kind)) continue;
      if (!rects.containsKey(edge.fromId) || !rects.containsKey(edge.toId)) {
        continue;
      }
      byNode.putIfAbsent(edge.fromId, () => []).add((edge, edge.toId));
      byNode.putIfAbsent(edge.toId, () => []).add((edge, edge.fromId));
    }

    final ports = <String, double>{};
    for (final entry in byNode.entries) {
      final rect = rects[entry.key]!;
      final connections = entry.value
        ..sort(
          (a, b) => rects[a.$2]!.center.dx.compareTo(rects[b.$2]!.center.dx),
        );
      for (var index = 0; index < connections.length; index++) {
        final edge = connections[index].$1;
        ports['${_edgeKey(edge)}@${entry.key}'] =
            rect.left + rect.width * (index + 1) / (connections.length + 1);
      }
    }
    return ports;
  }

  static double _widthOf(MapNode node) => switch (node.kind) {
    MapNodeKind.you || MapNodeKind.end => smallWidth,
    _ => nodeWidth,
  };
}
