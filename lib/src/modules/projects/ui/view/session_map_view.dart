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
import 'package:keel_ui/src/modules/projects/ui/widget/map_callout_box.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/map_node_card.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

/// Debajo de esto el nodo pierde el pie: a esa escala se mira la forma del
/// recorrido, no los detalles de cada cuadro.
const _kDenseBelow = 0.5;

const _kMinScale = 0.25;
const _kMaxScale = 2.0;

/// El mapa de la sesión: un lienzo que se recorre, con el grafo de trabajo en
/// el centro y los árboles de consulta/delegación debajo.
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

  /// Encuadra lo DIBUJADO, no el lienzo. El lienzo tiene aire alrededor a
  /// propósito —para poder arrastrar más allá del último nodo— y encuadrarlo
  /// entero dejaba el mapa chiquito en el medio de la nada.
  void _fit(MapLayout layout) {
    if (_viewport.isEmpty) return;
    final content = layout.contentBounds;
    final scale = math
        .min(_viewport.width / content.width, _viewport.height / content.height)
        .clamp(_kMinScale, 1.0);
    _moveTo(
      Matrix4.identity()
        ..translateByDouble(
          (_viewport.width - content.width * scale) / 2 - content.left * scale,
          (_viewport.height - content.height * scale) / 2 - content.top * scale,
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
                      // El viñeteado, sobre el viewport y no sobre el lienzo:
                      // apaga los bordes de lo que estás mirando, que es lo
                      // que hace que el centro se lea como el centro.
                      const Positioned.fill(
                        child: IgnorePointer(child: _Vignette()),
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

class _Vignette extends StatelessWidget {
  const _Vignette();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 0.95,
          colors: [
            Colors.transparent,
            scheme.surfaceContainerLowest.withValues(alpha: 0.55),
          ],
          stops: const [0.45, 1],
        ),
      ),
    );
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
          _LaneLabel(y: layout.guideTopY, icon: Icons.reply, label: 'vuelve'),
          _LaneLabel(
            y: layout.guideRowY,
            icon: Icons.trending_flat,
            label: 'avanza',
          ),
          if (map.nodes.any((node) => node.lane > 0))
            _LaneLabel(
              y: layout.guideLaneY,
              icon: Icons.account_tree_outlined,
              label: 'delega',
            ),
          ..._consultCallouts(),
          for (final node in map.nodes)
            if (layout.rectOf(node.id) case final rect?)
              Positioned(
                left: rect.left,
                top: rect.top,
                // El ancho del CUADRO, no el del nodo: lo que resolvió se
                // pasa hacia la derecha, y al ancho de la cabeza entraban dos
                // palabras por línea.
                width: MapLayout.resolutionWidth,
                child: MapNodeCard(
                  node: node,
                  headWidth: rect.width,
                  dense: dense,
                  onTap: () => onOpen(node),
                  onExpandSubagents: () => onExpand(node.id),
                  onOpenConsults: () => onOpen(node),
                ),
              ),
        ],
      ),
    );
  }

  /// Los cuadros de réplica, uno por par. Dónde cae cada uno lo decide la
  /// geometría —dos cuadros encimados no dicen ninguno de los dos— y acá solo
  /// se dibujan.
  List<Widget> _consultCallouts() {
    return [
      for (final callout in map.callouts)
        if (layout.calloutRects[callout.pairId] case final rect?)
          Positioned(
            left: rect.left,
            // Se ancla por el CENTRO, no por arriba: `rect.center.dy` es
            // justo el punto entre la ida y la vuelta, y la traslación de
            // media altura lo deja parado ahí mida lo que mida.
            //
            // Sin esto había que fijarle el alto, y con el alto fijo una
            // respuesta de una línea ocupaba lo mismo que una de dos: todos
            // los cuadros idénticos, que es información tirada a la basura.
            // `MapLayout.calloutHeight` sigue siendo el alto RESERVADO —el
            // máximo— y por eso las filas no se tocan aunque el de arriba
            // mida menos.
            top: rect.center.dy,
            width: rect.width,
            child: FractionalTranslation(
              translation: const Offset(0, -0.5),
              child: _ConsultCallout(
                callout: callout,
                onOpen: () {
                  final node = map.nodeById(callout.answererId);
                  if (node != null) onOpen(node);
                },
              ),
            ),
          ),
    ];
  }
}

/// El cuadro de una réplica: quién le preguntó a quién y qué se dijeron.
///
/// Con la consulta en vuelo muestra el PEDIDO, en violeta y encendido; una
/// vez cerrada, el MISMO cuadro pasa a mostrar la respuesta, apagado. No
/// aparece otro debajo — es la regla de que las consultas cambian de estado
/// en vez de acumularse.
class _ConsultCallout extends StatelessWidget {
  const _ConsultCallout({required this.callout, required this.onOpen});

  final MapCallout callout;

  /// Abre la ficha del que contesta, donde está el intercambio entero. Lo que
  /// entra en el cuadro es la primera frase: el resto se lee tocándolo.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = callout.live
        ? kMapConsultColor
        : scheme.outline.withValues(alpha: 0.85);

    return Tooltip(
      message: 'Ver la consulta entera',
      waitDuration: const Duration(milliseconds: 600),
      child: MapCalloutBox(
        icon: callout.live ? Icons.reply : Icons.subdirectory_arrow_left,
        label: callout.title,
        text: callout.text,
        color: color,
        maxLines: 2,
        opaque: true,
        onTap: onOpen,
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
      top: y - 8,
      child: Container(
        color: scheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 8),
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
