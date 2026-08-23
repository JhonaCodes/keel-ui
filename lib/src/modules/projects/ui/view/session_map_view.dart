import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/session_map.dart';
import 'package:keel_ui/src/modules/projects/model/session_map_layout.dart';
import 'package:keel_ui/src/modules/projects/ui/screen/map_node_inspector_screen.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/map_edges_painter.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/map_legend.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/map_node_card.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

/// Debajo de esto el nodo pierde el pie: a esa escala se mira la forma del
/// recorrido, no los detalles de cada cuadro.
const _kDenseBelow = 0.5;

const _kMinScale = 0.25;
const _kMaxScale = 2.0;

/// El mapa de la sesión: un lienzo que se recorre, con carriles fijos —arriba
/// vuelve, al medio avanza, abajo se delega— y nodos que cambian de estado.
///
/// Reemplaza al carril vertical con arcos que había antes, que contaba quién
/// le pasó a quién —lo que el hilo ya decía— y nada de lo que uno quiere
/// mirar: en qué anda cada uno, qué está razonando, y qué pasa adentro de un
/// subagente.
class SessionMapView extends StatefulWidget {
  const SessionMapView({
    super.key,
    required this.project,
    required this.session,
    required this.members,
    required this.workflow,
  });

  final Project project;
  final Session? session;
  final List<AgentProfile> members;
  final Workflow? workflow;

  @override
  State<SessionMapView> createState() => _SessionMapViewState();
}

class _SessionMapViewState extends State<SessionMapView>
    with TickerProviderStateMixin {
  final _view = TransformationController();

  /// Mueve los guiones y el punto que viaja. Corre SOLO cuando hay algo
  /// viajando: un timer que late siempre es exactamente lo que arreglamos en
  /// otro lado de la app.
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  late final AnimationController _camera = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  Animation<Matrix4>? _cameraTween;

  final Set<String> _expanded = {};
  bool _follow = true;
  bool _legend = false;
  bool _dense = false;
  String? _centeredOn;
  Size _viewport = Size.zero;

  @override
  void initState() {
    super.initState();
    _view.addListener(_watchScale);
    _camera.addListener(() {
      final tween = _cameraTween;
      if (tween != null) _view.value = tween.value;
    });
  }

  @override
  void dispose() {
    _view.removeListener(_watchScale);
    _view.dispose();
    _flow.dispose();
    _camera.dispose();
    super.dispose();
  }

  double get _scale => _view.value.getMaxScaleOnAxis();

  void _watchScale() {
    final dense = _scale < _kDenseBelow;
    if (dense != _dense) setState(() => _dense = dense);
  }

  void _zoomBy(double factor) {
    // Cortar la cámara primero: si venía moviéndose, su tick pisa el zoom en
    // el frame siguiente y el botón parece no hacer nada.
    _camera.stop();
    final target = (_scale * factor).clamp(_kMinScale, _kMaxScale);
    if (target == _scale) return;
    final anchor = _view.toScene(_viewport.center(Offset.zero));
    final applied = target / _scale;
    _view.value = _view.value.clone()
      ..translateByDouble(anchor.dx, anchor.dy, 0, 1)
      ..scaleByDouble(applied, applied, applied, 1)
      ..translateByDouble(-anchor.dx, -anchor.dy, 0, 1);
  }

  void _fit(MapLayout layout) {
    if (_viewport.isEmpty) return;
    final scale = math
        .min(
          _viewport.width / layout.size.width,
          _viewport.height / layout.size.height,
        )
        .clamp(_kMinScale, 1.0);
    _moveTo(
      Matrix4.identity()
        ..translateByDouble(
          (_viewport.width - layout.size.width * scale) / 2,
          (_viewport.height - layout.size.height * scale) / 2,
          0,
          1,
        )
        ..scaleByDouble(scale, scale, scale, 1),
    );
  }

  void _center(Rect rect, {double? scale}) {
    if (_viewport.isEmpty) return;
    final zoom = scale ?? _scale;
    _moveTo(
      Matrix4.identity()
        ..translateByDouble(
          _viewport.width / 2 - rect.center.dx * zoom,
          _viewport.height / 2 - rect.center.dy * zoom,
          0,
          1,
        )
        ..scaleByDouble(zoom, zoom, zoom, 1),
    );
  }

  void _moveTo(Matrix4 target) {
    _cameraTween = Matrix4Tween(
      begin: _view.value,
      end: target,
    ).animate(CurvedAnimation(parent: _camera, curve: Curves.easeOutCubic));
    _camera.forward(from: 0);
  }

  /// Seguir en vivo se apaga sola en cuanto arrastrás: mirar algo y que la
  /// vista se te escape es peor que no seguir nada.
  void _handOver() {
    _camera.stop();
    if (_follow) setState(() => _follow = false);
  }

  void _openNode(MapNode node) {
    if (node.kind == MapNodeKind.you || node.kind == MapNodeKind.end) return;
    openMapNodeInspector(
      context,
      project: widget.project,
      node: node,
      members: widget.members,
    );
  }

  @override
  Widget build(BuildContext context) {
    final map = SessionMap.from(
      session: widget.session,
      members: widget.members,
      workflow: widget.workflow,
      expandedParents: _expanded,
    );
    final layout = MapLayout.of(map);

    if (map.isEmpty) return const _EmptyMap();

    final live = map.nodes.where((node) => node.isLive).firstOrNull;
    _syncFlow(map, live, layout);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.digit0, meta: true): () =>
            _fit(layout),
        const SingleActivator(LogicalKeyboardKey.equal, meta: true): () =>
            _zoomBy(1.25),
        const SingleActivator(LogicalKeyboardKey.minus, meta: true): () =>
            _zoomBy(0.8),
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            ListenableBuilder(
              listenable: _view,
              builder: (context, _) => _MapBar(
                scale: _scale,
                following: _follow,
                legendOpen: _legend,
                onZoomIn: () => _zoomBy(1.25),
                onZoomOut: () => _zoomBy(0.8),
                onFit: () => _fit(layout),
                onToggleFollow: () => setState(() => _follow = !_follow),
                onToggleLegend: () => setState(() => _legend = !_legend),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _viewport = constraints.biggest;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: InteractiveViewer(
                          transformationController: _view,
                          constrained: false,
                          minScale: _kMinScale,
                          maxScale: _kMaxScale,
                          boundaryMargin: const EdgeInsets.all(600),
                          onInteractionStart: (_) => _handOver(),
                          child: _Canvas(
                            map: map,
                            layout: layout,
                            flow: _flow,
                            dense: _dense,
                            onOpen: _openNode,
                            onExpand: (id) => setState(() => _expanded.add(id)),
                          ),
                        ),
                      ),
                      if (_legend)
                        Positioned(
                          right: 14,
                          bottom: 14,
                          child: MapLegend(
                            onClose: () => setState(() => _legend = false),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Enciende el movimiento solo si hay algo en vuelo, y persigue al nodo que
  /// tiene el turno cuando «seguir en vivo» está prendido.
  void _syncFlow(SessionMap map, MapNode? live, MapLayout layout) {
    final moving = map.edges.any((edge) => edge.live);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (moving && !_flow.isAnimating) {
        _flow.repeat();
      } else if (!moving && _flow.isAnimating) {
        _flow.stop();
      }

      if (!_follow) return;
      // Sin nadie con el turno, la vista se para en el último que habló y no
      // en el principio: abrir el mapa a mitad de una sesión y mirar el
      // arranque es mirar el pasado.
      final target =
          live ??
          map.nodes.lastWhere(
            (node) => node.lane == 0 && node.state != MapNodeState.idle,
            orElse: () => map.nodes.first,
          );
      if (target.id == _centeredOn) return;
      final rect = layout.rectOf(target.id);
      if (rect == null) return;
      _centeredOn = target.id;
      _center(rect);
    });
  }
}

class _Canvas extends StatelessWidget {
  const _Canvas({
    required this.map,
    required this.layout,
    required this.flow,
    required this.dense,
    required this.onOpen,
    required this.onExpand,
  });

  final SessionMap map;
  final MapLayout layout;
  final Animation<double> flow;
  final bool dense;
  final ValueChanged<MapNode> onOpen;
  final ValueChanged<String> onExpand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // El lienzo pinta su propio fondo: las etiquetas de carril lo recortan
    // para abrirse paso entre los guiones, y eso solo funciona si el color
    // que usan es el que hay atrás de verdad.
    return Container(
      width: layout.size.width,
      height: layout.size.height,
      color: scheme.surface,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: flow,
              builder: (context, child) => CustomPaint(
                size: layout.size,
                painter: MapEdgesPainter(
                  map: map,
                  layout: layout,
                  scheme: scheme,
                  progress: flow.value,
                ),
              ),
            ),
          ),
          const _LaneLabel(
            y: MapLayout.guideTopY,
            icon: Icons.reply,
            label: 'vuelve',
          ),
          const _LaneLabel(
            y: MapLayout.guideRowY,
            icon: Icons.trending_flat,
            label: 'avanza',
          ),
          if (map.nodes.any((node) => node.lane > 0))
            const _LaneLabel(
              y: MapLayout.guideLaneY,
              icon: Icons.account_tree_outlined,
              label: 'delega',
            ),
          ..._consultCallouts(),
          for (final node in map.nodes)
            if (layout.rectOf(node.id) case final rect?)
              Positioned(
                left: rect.left,
                top: rect.top,
                width: rect.width,
                child: MapNodeCard(
                  node: node,
                  dense: dense,
                  onTap: () => onOpen(node),
                  onExpandSubagents: () => onExpand(node.id),
                ),
              ),
        ],
      ),
    );
  }

  /// El cuadro de una consulta se dibuja SOLO mientras está viva. Las
  /// cerradas quedan como el arco tenue y el contador en el pie del nodo:
  /// diez idas y vueltas son una píldora que dice 10, no diez cuadros.
  List<Widget> _consultCallouts() {
    return [
      for (final edge in map.edges)
        if (edge.live && edge.kind == MapEdgeKind.back && edge.label.isNotEmpty)
          if (layout.rectOf(edge.fromId) case final from?)
            if (layout.rectOf(edge.toId) case final to?)
              Positioned(
                left: (from.center.dx + to.center.dx) / 2 - 130,
                top: MapLayout.calloutTopY,
                width: 260,
                child: _ConsultCallout(
                  from: map.nodeById(edge.fromId)?.label ?? '',
                  to: map.nodeById(edge.toId)?.label ?? '',
                  text: edge.label,
                ),
              ),
    ];
  }
}

class _ConsultCallout extends StatelessWidget {
  const _ConsultCallout({
    required this.from,
    required this.to,
    required this.text,
  });

  final String from;
  final String to;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.97),
        border: Border.all(color: kMapConsultColor),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.reply, size: 11, color: kMapConsultColor),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  '$from → $to'.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    letterSpacing: 1,
                    color: kMapConsultColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _LaneLabel extends StatelessWidget {
  const _LaneLabel({required this.y, required this.icon, required this.label});

  final double y;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Positioned(
      left: 12,
      top: y - 9,
      child: Container(
        color: scheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: scheme.outline),
            const SizedBox(width: 5),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                letterSpacing: 1.3,
                color: scheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapBar extends StatelessWidget {
  const _MapBar({
    required this.scale,
    required this.following,
    required this.legendOpen,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
    required this.onToggleFollow,
    required this.onToggleLegend,
  });

  final double scale;
  final bool following;
  final bool legendOpen;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;
  final VoidCallback onToggleFollow;
  final VoidCallback onToggleLegend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Angosta, la barra suelta las etiquetas y se queda con los iconos.
    // Que los botones se recorten es peor que no poder leerlos: un botón a
    // medias no se puede apretar.
    return LayoutBuilder(
      builder: (context, constraints) {
        final showLabels = constraints.maxWidth >= 700;
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
          color: scheme.surfaceContainerLow,
          child: Row(
            children: [
              _BarButton(
                icon: Icons.zoom_out,
                tooltip: 'Alejar  ⌘−',
                onPressed: onZoomOut,
              ),
              SizedBox(
                width: 46,
                child: Text(
                  '${(scale * 100).round()}%',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10.5,
                    color: scheme.outline,
                  ),
                ),
              ),
              _BarButton(
                icon: Icons.zoom_in,
                tooltip: 'Acercar  ⌘+',
                onPressed: onZoomIn,
              ),
              const SizedBox(width: 8),
              _BarButton(
                icon: Icons.fit_screen_outlined,
                label: showLabels ? 'Encuadrar' : null,
                tooltip: 'Meter todo en pantalla  ⌘0',
                onPressed: onFit,
              ),
              const SizedBox(width: 6),
              _BarButton(
                icon: Icons.visibility_outlined,
                label: showLabels ? 'Seguir en vivo' : null,
                tooltip: 'Perseguir al nodo que tiene el turno',
                active: following,
                onPressed: onToggleFollow,
              ),
              const SizedBox(width: 6),
              _BarButton(
                icon: Icons.legend_toggle,
                label: showLabels ? 'Leyenda' : null,
                tooltip: 'Qué significa cada línea',
                active: legendOpen,
                onPressed: onToggleLegend,
              ),
              // La ayuda se recorta antes que los botones: es lo único de la
              // barra que uno deja de leer después de la primera vez.
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'arrastrar = mover · ⌘ + rueda = zoom',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9.5,
                      color: scheme.outline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.onPressed,
    this.label,
    this.tooltip,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? label;
  final String? tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active ? scheme.primary : scheme.onSurfaceVariant;

    final button = Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 26,
          padding: EdgeInsets.symmetric(horizontal: label == null ? 7 : 9),
          decoration: BoxDecoration(
            border: Border.all(
              color: active ? scheme.primary : scheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              if (label != null) ...[
                const SizedBox(width: 6),
                Text(label!, style: TextStyle(fontSize: 11.5, color: color)),
              ],
            ],
          ),
        ),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _EmptyMap extends StatelessWidget {
  const _EmptyMap();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hub_outlined, size: 36, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              'Este proyecto todavía no tiene a quién mapear',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Sumale miembros y un workflow: el mapa se abre con el elenco '
              'puesto, en reposo, antes de que corra nada.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
