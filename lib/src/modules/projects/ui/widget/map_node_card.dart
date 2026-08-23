import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/agents/ui/widget/agent_activity_indicator.dart';
import 'package:keel_ui/src/modules/projects/model/member_color.dart';
import 'package:keel_ui/src/modules/projects/model/session_map.dart';
import 'package:keel_ui/src/modules/projects/model/session_map_layout.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/map_edges_painter.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/turn_phase_label.dart';

/// El color de un estado. El icono dice QUÉ pasa; el borde, en qué familia
/// cae: acento cuando el nodo tiene el turno, verde cuando cerró, rojo cuando
/// cortó, violeta cuando está contestando hacia atrás.
Color mapStateColor(MapNodeState state, ColorScheme scheme) => switch (state) {
  MapNodeState.idle => scheme.outlineVariant,
  MapNodeState.thinking => kProjectMemberPalette[6],
  MapNodeState.working => scheme.primary,
  MapNodeState.writing => kProjectMemberPalette[0],
  MapNodeState.replying => kMapConsultColor,
  MapNodeState.waiting => scheme.primary,
  MapNodeState.done => scheme.tertiary,
  MapNodeState.failed => scheme.error,
};

IconData mapStateIcon(MapNodeState state) => switch (state) {
  MapNodeState.idle => Icons.circle_outlined,
  MapNodeState.thinking => Icons.psychology_outlined,
  MapNodeState.working => Icons.bolt_outlined,
  MapNodeState.writing => Icons.edit_note,
  MapNodeState.replying => Icons.reply,
  MapNodeState.waiting => Icons.lock_outline,
  MapNodeState.done => Icons.check,
  MapNodeState.failed => Icons.warning_amber_rounded,
};

/// Un agente en el mapa: **un solo cuadro que cambia de estado**.
///
/// Nada se apila, nada crece hacia abajo salvo el cuadro punteado de lo que
/// resolvió, y lo que ya pasó queda como número en el pie —no como otro
/// cuadro en el lienzo.
class MapNodeCard extends StatelessWidget {
  const MapNodeCard({
    super.key,
    required this.node,
    required this.onTap,
    this.onExpandSubagents,
    this.dense = false,
  });

  final MapNode node;
  final VoidCallback onTap;
  final VoidCallback? onExpandSubagents;

  /// Alejado, el pie se va: a esa escala se mira la forma del recorrido, no
  /// los detalles de cada nodo.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = node.colorIndex >= 0
        ? memberColorFor(node.colorIndex)
        : scheme.primary;
    final stateColor = mapStateColor(node.state, scheme);
    final idle = node.state == MapNodeState.idle;

    final head = _Head(
      node: node,
      accent: accent,
      stateColor: stateColor,
      dense: dense,
      onExpandSubagents: onExpandSubagents,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: SizedBox(
              height: MapLayout.nodeHeight,
              child: node.isLive ? _Halo(color: stateColor, child: head) : head,
            ),
          ),
        ),
        if (!dense && !idle) _Resolution(node: node, onTap: onTap),
      ],
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({
    required this.node,
    required this.accent,
    required this.stateColor,
    required this.dense,
    this.onExpandSubagents,
  });

  final MapNode node;
  final Color accent;
  final Color stateColor;
  final bool dense;
  final VoidCallback? onExpandSubagents;

  /// Vos y el fin no llevan pie: no hay paso, ni tiempo, ni herramienta que
  /// contar, y un pie vacío es una línea divisoria que no divide nada.
  bool get bare => node.kind == MapNodeKind.you || node.kind == MapNodeKind.end;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final idle = node.state == MapNodeState.idle;

    return Container(
      padding: bare
          ? const EdgeInsets.symmetric(horizontal: 9, vertical: 8)
          : const EdgeInsets.fromLTRB(9, 8, 9, 7),
      decoration: BoxDecoration(
        color: idle
            ? scheme.surfaceContainerLow.withValues(alpha: 0.55)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: stateColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      alignment: bare ? Alignment.centerLeft : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _Glyph(node: node, accent: accent),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  node.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    color: idle ? scheme.onSurfaceVariant : scheme.onSurface,
                  ),
                ),
              ),
              Icon(mapStateIcon(node.state), size: 13, color: stateColor),
            ],
          ),
          if (!dense && !bare) ...[
            const SizedBox(height: 5),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 4),
            SizedBox(
              height: 18,
              child: _Foot(
                node: node,
                accent: accent,
                onExpandSubagents: onExpandSubagents,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// El pie: mientras el nodo tiene el turno son los MISMOS indicadores
/// animados que muestra el chat —el icono de la herramienta que gira y la
/// línea que respira—, no una copia parecida. Cuando cierra, son números.
class _Foot extends StatelessWidget {
  const _Foot({
    required this.node,
    required this.accent,
    this.onExpandSubagents,
  });

  final MapNode node;
  final Color accent;
  final VoidCallback? onExpandSubagents;

  @override
  Widget build(BuildContext context) {
    final activity = node.activity;
    if (activity != null) return AgentActivityIndicator(activity: activity);

    final phase = node.phase;
    if (phase != null) {
      return TurnPhaseLabel(phase: phase, accent: accent, compact: true);
    }

    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (node.stepIndex case final step?)
          _Chip(label: 'paso ${step + 1}')
        else if (node.kind == MapNodeKind.subagent)
          _Chip(label: 'subagente'),
        if (node.elapsed > Duration.zero) ...[
          const SizedBox(width: 8),
          _Count(icon: Icons.schedule, label: _clock(node.elapsed)),
        ],
        if (node.backCalls > 0) ...[
          const SizedBox(width: 8),
          _Count(
            icon: Icons.reply,
            label: '${node.backCalls}',
            color: kMapConsultColor,
          ),
        ],
        if (node.subagentCount > 0) ...[
          const SizedBox(width: 8),
          _Count(
            icon: Icons.account_tree_outlined,
            label: '${node.subagentCount}',
            color: kMapDelegateColor,
            onTap: node.hiddenSubagents > 0 ? onExpandSubagents : null,
          ),
        ],
        const Spacer(),
        if (node.state == MapNodeState.done && node.reasoning.isNotEmpty)
          Icon(Icons.psychology_outlined, size: 12, color: scheme.outline),
      ],
    );
  }

  static String _clock(Duration elapsed) {
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({required this.node, required this.accent});

  final MapNode node;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color, filled) = switch (node.kind) {
      MapNodeKind.you => (Icons.person_outline, scheme.primary, true),
      MapNodeKind.end => (Icons.flag_outlined, scheme.outline, false),
      MapNodeKind.subagent => (
        Icons.account_tree_outlined,
        kMapDelegateColor,
        false,
      ),
      _ => (Icons.smart_toy, accent, true),
    };

    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.18) : null,
        borderRadius: BorderRadius.circular(7),
        border: filled ? null : Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Icon(icon, size: 13, color: color),
    );
  }
}

/// El cuadro punteado: qué resolvió, en pocas palabras.
///
/// Uno por nodo cerrado y nunca dos. Si el mismo nodo vuelve a hablar, este
/// cuadro se reescribe — no aparece otro debajo.
class _Resolution extends StatelessWidget {
  const _Resolution({required this.node, required this.onTap});

  final MapNode node;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (label, icon, color, body) = switch (node.state) {
      MapNodeState.failed => (
        'cortó',
        Icons.warning_amber_rounded,
        scheme.error,
        node.resolved,
      ),
      MapNodeState.done when node.answeredOnly => (
        'contestó',
        Icons.reply,
        kMapConsultColor,
        node.resolved,
      ),
      MapNodeState.done => (
        'resolvió',
        Icons.check,
        scheme.tertiary,
        node.resolved,
      ),
      _ => (
        'pensando',
        Icons.psychology_outlined,
        kProjectMemberPalette[6],
        _tailOf(node.reasoning),
      ),
    };
    if (body.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: CustomPaint(
            painter: _DashedBoxPainter(color: color.withValues(alpha: 0.75)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 11, color: color),
                      const SizedBox(width: 5),
                      Text(
                        label.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9,
                          letterSpacing: 1,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// La cola del razonamiento, no su principio: lo que el agente está
  /// pensando AHORA es lo último que escribió.
  static String _tailOf(String reasoning) {
    final flat = reasoning.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.length <= 130) return flat;
    return '…${flat.substring(flat.length - 130)}';
  }
}

class _DashedBoxPainter extends CustomPainter {
  const _DashedBoxPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(7)),
      );

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
  bool shouldRepaint(_DashedBoxPainter old) => old.color != color;
}

/// El anillo que respira. Solo lo lleva el nodo que tiene el turno AHORA —
/// que es lo que hace que se lea de un vistazo dónde está el trabajo.
class _Halo extends StatefulWidget {
  const _Halo({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  State<_Halo> createState() => _HaloState();
}

class _HaloState extends State<_Halo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOut.transform(_controller.value);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Transform.scale(
                scale: 0.98 + 0.07 * t,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.color.withValues(alpha: 0.42 * (1 - t)),
                    ),
                  ),
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 9,
          color: scheme.outline,
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.outline;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: tint),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: tint),
        ),
      ],
    );
    if (onTap == null) return row;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: row),
    );
  }
}
