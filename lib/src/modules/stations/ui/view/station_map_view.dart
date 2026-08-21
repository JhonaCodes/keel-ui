import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/stations/model/station_task.dart';
import 'package:keel_ui/src/modules/agent_profiles/ui/screen/agent_profile_form_screen.dart';
import 'package:keel_ui/src/modules/stations/model/task_graph.dart';
import 'package:keel_ui/src/modules/stations/ui/widget/station_graph_painter.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

/// The same conversation as a network, played back hop by hop: who had it,
/// who they asked, and where the work went next.
class StationMapView extends StatefulWidget {
  const StationMapView({
    super.key,
    required this.task,
    required this.members,
    required this.workflow,
  });

  final StationTask? task;
  final List<AgentProfile> members;
  final Workflow? workflow;

  @override
  State<StationMapView> createState() => _StationMapViewState();
}

class _StationMapViewState extends State<StationMapView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration.zero,
  );

  static const _perEdge = Duration(milliseconds: 1400);

  @override
  void initState() {
    super.initState();
    _retune(play: true);
  }

  @override
  void didUpdateWidget(StationMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_graph.edges.length != _tunedEdges) _retune(play: true);
  }

  int _tunedEdges = 0;

  TaskGraph get _graph => TaskGraph.fromMessages(
    messages: widget.task?.messages ?? const [],
    members: widget.members,
    stepTitles: [
      for (final step in widget.workflow?.steps ?? const []) step.title,
    ],
  );

  void _retune({required bool play}) {
    final count = _graph.edges.length;
    _tunedEdges = count;
    _controller.duration = _perEdge * (count == 0 ? 1 : count);
    _controller.reset();
    if (play && count > 0) _controller.repeat();
  }

  void _togglePlay() {
    setState(() {
      if (_controller.isAnimating) {
        _controller.stop();
        return;
      }
      if (_controller.value >= 1) _controller.reset();
      _controller.repeat();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Opens the specs of the agent behind a node. This is how a subagent one
  /// of the members brought in stops being a name on a line: you can read the
  /// role and the instructions it was registered with.
  void _openSpecs(TaskGraphNode? node) {
    if (node == null || node.isUser) return;
    final profile = widget.members
        .where((member) => member.id == node.id)
        .firstOrNull;
    if (profile == null) return;
    openAgentProfileFormScreen(context, initial: profile);
  }

  @override
  Widget build(BuildContext context) {
    final graph = _graph;
    if (graph.isEmpty) return const _EmptyMap();

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Only for hit-testing: the layout depends on the graph and
                // the canvas size, never on playback progress.
                final hitTester = StationGraphPainter(
                  graph: graph,
                  progress: 0,
                  scheme: Theme.of(context).colorScheme,
                  textDirection: Directionality.of(context),
                );
                final size = constraints.biggest;

                return GestureDetector(
                  onTapUp: (details) =>
                      _openSpecs(hitTester.nodeAt(size, details.localPosition)),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) => CustomPaint(
                      painter: StationGraphPainter(
                        graph: graph,
                        progress: _controller.value,
                        scheme: Theme.of(context).colorScheme,
                        textDirection: Directionality.of(context),
                      ),
                      size: Size.infinite,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        _MapControls(
          controller: _controller,
          onTogglePlay: _togglePlay,
          edgeCount: graph.edges.length,
        ),
      ],
    );
  }
}

class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.controller,
    required this.onTogglePlay,
    required this.edgeCount,
  });

  final AnimationController controller;
  final VoidCallback onTogglePlay;
  final int edgeCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            tooltip: controller.isAnimating ? 'Pausar' : 'Reproducir',
            onPressed: onTogglePlay,
            icon: AnimatedBuilder(
              animation: controller,
              builder: (context, child) =>
                  Icon(controller.isAnimating ? Icons.pause : Icons.play_arrow),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: _Scrubber(controller: controller)),
          const SizedBox(width: 18),
          _Legend(
            color: scheme.primary,
            style: _LegendStyle.solid,
            label: 'Paso del workflow',
          ),
          const SizedBox(width: 14),
          _Legend(
            color: scheme.tertiary,
            style: _LegendStyle.dashed,
            label: 'Consulta',
          ),
          const SizedBox(width: 14),
          _Legend(
            color: scheme.secondary,
            style: _LegendStyle.dashed,
            label: 'Creó al agente',
          ),
          const SizedBox(width: 14),
          _Legend(
            color: scheme.outline,
            style: _LegendStyle.node,
            label: 'Sin tocar',
          ),
        ],
      ),
    );
  }
}

/// A real scrub bar: drag it to move through the playback. A progress
/// indicator only reports; this lets you go back to the hop you missed.
class _Scrubber extends StatelessWidget {
  const _Scrubber({required this.controller});

  final AnimationController controller;

  void _seek(Offset localPosition, double width) {
    if (width <= 0) return;
    controller.stop();
    controller.value = (localPosition.dx / width).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) =>
            _seek(details.localPosition, constraints.maxWidth),
        onHorizontalDragStart: (details) =>
            _seek(details.localPosition, constraints.maxWidth),
        onHorizontalDragUpdate: (details) =>
            _seek(details.localPosition, constraints.maxWidth),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: SizedBox(
            height: 18,
            child: Center(
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, child) => LinearProgressIndicator(
                  value: controller.value,
                  minHeight: 3,
                  backgroundColor: scheme.outlineVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _LegendStyle { solid, dashed, node }

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.style,
    required this.label,
  });

  final Color color;
  final _LegendStyle style;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 22,
          child: _LegendSwatch(color: color, style: style),
        ),
        const SizedBox(width: 7),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({required this.color, required this.style});

  final Color color;
  final _LegendStyle style;

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      _LegendStyle.solid => Container(height: 2, color: color),
      _LegendStyle.dashed => Row(
        children: [
          for (var index = 0; index < 3; index++) ...[
            Expanded(child: Container(height: 2, color: color)),
            if (index < 2) const SizedBox(width: 3),
          ],
        ],
      ),
      _LegendStyle.node => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    };
  }
}

class _EmptyMap extends StatelessWidget {
  const _EmptyMap();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hub_outlined,
              size: 36,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'Todavía no hay nada que mapear',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Cuando el workflow reparta los pasos, acá vas a ver quién lo '
              'tiene, a quién le pregunta y por dónde sigue el trabajo.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
