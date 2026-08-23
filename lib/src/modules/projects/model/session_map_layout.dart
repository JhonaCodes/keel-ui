import 'dart:ui';

import 'package:keel_ui/src/modules/projects/model/session_map.dart';

/// Dónde cae cada nodo en el lienzo, en píxeles.
///
/// Es geometría pura y determinista: la misma sesión da siempre el mismo
/// dibujo. Los nodos NO se pueden arrastrar a propósito — una disposición que
/// el usuario puede desordenar es una que hay que guardar, migrar y arreglar
/// cuando queda rara, y lo que se gana es nada.
class MapLayout {
  /// La caja del nodo que usan las aristas. Lo que cuelgue abajo —el cuadro
  /// punteado de «resolvió»— crece fuera de esta caja: las líneas apuntan a la
  /// cabeza del nodo, no a su texto.
  static const nodeWidth = 176.0;
  static const smallWidth = 112.0;
  static const nodeHeight = 70.0;

  static const columnGap = 56.0;
  static const padLeft = 28.0;
  static const padRight = 56.0;

  /// Las tres franjas fijas: arriba vuelve, al medio avanza, abajo se delega.
  /// Son siempre las mismas y en el mismo lugar, así que una línea que sube
  /// significa lo mismo en cualquier sesión sin tener que mirar la leyenda.
  static const guideTopY = 54.0;
  static const spawnApexY = 70.0;
  static const backApexY = 92.0;
  static const calloutTopY = 40.0;
  static const guideRowY = 128.0;
  static const rowY = 152.0;
  static const guideLaneY = 314.0;
  static const laneY = 338.0;

  /// Alto del nodo MÁS su cuadro punteado: con el paso justo, el subagente
  /// de abajo tapaba lo que devolvió el de arriba.
  static const laneSlotPitch = 150.0;
  static const bottomPad = 44.0;

  final Size size;
  final Map<String, Rect> _rects;
  final List<MapNode> nodes;

  const MapLayout._(this.size, this._rects, this.nodes);

  Rect? rectOf(String id) => _rects[id];

  /// El nodo que cae bajo un punto del lienzo, si hay alguno.
  MapNode? nodeAt(Offset point) {
    for (final node in nodes) {
      if (_rects[node.id]?.contains(point) ?? false) return node;
    }
    return null;
  }

  factory MapLayout.of(SessionMap map) {
    final columnWidth = <int, double>{};
    for (final node in map.nodes) {
      final width = switch (node.kind) {
        MapNodeKind.you || MapNodeKind.end => smallWidth,
        _ => nodeWidth,
      };
      final current = columnWidth[node.column] ?? 0;
      if (width > current) columnWidth[node.column] = width;
    }

    final columnX = <int, double>{};
    var x = padLeft;
    for (var column = 0; column < map.columns; column++) {
      columnX[column] = x;
      x += (columnWidth[column] ?? nodeWidth) + columnGap;
    }

    final rects = <String, Rect>{};
    var deepestSlot = 0;
    for (final node in map.nodes) {
      final width = switch (node.kind) {
        MapNodeKind.you || MapNodeKind.end => smallWidth,
        _ => nodeWidth,
      };
      final left = columnX[node.column] ?? padLeft;
      final top = node.lane == 0 ? rowY : laneY + node.laneSlot * laneSlotPitch;
      if (node.lane > 0 && node.laneSlot > deepestSlot) {
        deepestSlot = node.laneSlot;
      }
      rects[node.id] = Rect.fromLTWH(left, top, width, nodeHeight);
    }

    final hasLane = map.nodes.any((node) => node.lane > 0);
    final height = hasLane
        ? laneY + (deepestSlot + 1) * laneSlotPitch + bottomPad
        : rowY + nodeHeight + 150;

    return MapLayout._(
      Size(x - columnGap + padRight, height),
      rects,
      map.nodes,
    );
  }
}
