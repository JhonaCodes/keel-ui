import 'package:flutter/material.dart';

import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/agent_activity_indicator.dart';
import 'package:keel_ui/src/modules/projects/model/member_color.dart';
import 'package:keel_ui/src/modules/projects/model/session_map.dart';
import 'package:keel_ui/src/modules/projects/model/session_map_layout.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/map_callout_box.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/map_edges_painter.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/turn_phase_label.dart';

/// El color del BORDE de un estado. El icono dice QUÉ pasa; el borde, en qué
/// familia cae: acento cuando el nodo tiene el turno, teal cuando trabaja,
/// verde cuando cerró, rojo cuando cortó, violeta cuando contesta hacia atrás.
Color mapStateColor(MapNodeState state, ColorScheme scheme) => switch (state) {
  MapNodeState.idle => scheme.outlineVariant,
  MapNodeState.receiving => scheme.primary,
  MapNodeState.thinking => kProjectMemberPalette[6],
  MapNodeState.working => kProjectMemberPalette[1],
  MapNodeState.writing => kProjectMemberPalette[0],
  MapNodeState.replying => kMapConsultColor,
  MapNodeState.waiting => AppColors.brassDeep,
  MapNodeState.done => scheme.tertiary,
  MapNodeState.failed => scheme.error,
};

/// El color del ICONO de estado. Casi siempre es el del borde; la excepción
/// es «esperando permiso», que en el mockup lleva el borde brass-deep y el
/// candado en brass (`.nd.wait` vs `.nd.wait .st`).
Color mapStateIconColor(MapNodeState state, ColorScheme scheme) =>
    switch (state) {
      MapNodeState.waiting => scheme.primary,
      _ => mapStateColor(state, scheme),
    };

IconData mapStateIcon(MapNodeState state) => switch (state) {
  MapNodeState.idle => Icons.circle_outlined,
  MapNodeState.receiving => Icons.arrow_downward,
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
    required this.headWidth,
    this.onExpandSubagents,
    this.onOpenConsults,
    this.dense = false,
  });

  final MapNode node;
  final VoidCallback onTap;

  /// Lo ancha que va la CABEZA. El widget entero es más ancho, porque el
  /// cuadro de «resolvió» se pasa hacia la derecha.
  final double headWidth;

  final VoidCallback? onExpandSubagents;
  final VoidCallback? onOpenConsults;

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
      onOpenConsults: onOpenConsults,
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
              width: headWidth,
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
    this.onOpenConsults,
  });

  final MapNode node;
  final Color accent;
  final Color stateColor;
  final bool dense;
  final VoidCallback? onExpandSubagents;
  final VoidCallback? onOpenConsults;

  /// Vos y el fin no llevan pie: no hay paso, ni tiempo, ni herramienta que
  /// contar, y un pie vacío es una línea divisoria que no divide nada.
  bool get bare => node.kind == MapNodeKind.you || node.kind == MapNodeKind.end;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final idle = node.state == MapNodeState.idle;

    return Container(
      padding: bare
          ? const EdgeInsets.symmetric(horizontal: 9, vertical: 7)
          : const EdgeInsets.fromLTRB(9, 7, 9, 7),
      decoration: BoxDecoration(
        color: idle
            ? scheme.surfaceContainerLow.withValues(alpha: 0.55)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: stateColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
                    fontSize: 11,
                    color: idle ? scheme.onSurfaceVariant : scheme.onSurface,
                  ),
                ),
              ),
              if (node.state == MapNodeState.receiving)
                _BlinkingIcon(
                  icon: mapStateIcon(node.state),
                  color: mapStateIconColor(node.state, scheme),
                  size: 13,
                )
              else
                Icon(
                  mapStateIcon(node.state),
                  size: 13,
                  color: mapStateIconColor(node.state, scheme),
                ),
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
                onOpenConsults: onOpenConsults,
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
    this.onOpenConsults,
  });

  final MapNode node;
  final Color accent;
  final VoidCallback? onExpandSubagents;
  final VoidCallback? onOpenConsults;

  @override
  Widget build(BuildContext context) {
    final activity = node.activity;
    if (activity != null) return AgentActivityIndicator(activity: activity);

    final phase = node.phase;
    if (phase != null) {
      return TurnPhaseLabel(phase: phase, accent: accent, compact: true);
    }

    return Row(
      children: [
        // Achica en vez de desbordar. Un nodo con paso, reloj, réplicas y
        // subagentes a la vez no entra en el ancho de la cabeza, y ninguno de
        // los cuatro sobra: preferimos leerlos un punto más chicos que
        // perder uno.
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (node.kind == MapNodeKind.consultation)
                  _Chip(label: 'consulta')
                else if (node.workNodeId != null)
                  _Chip(label: node.nodeTitle)
                else if (node.kind == MapNodeKind.subagent)
                  _Chip(label: 'subagente'),
                if (node.elapsed > Duration.zero) ...[
                  const SizedBox(width: 8),
                  _Count(icon: Icons.schedule, label: _clock(node.elapsed)),
                ],
                if (node.kind == MapNodeKind.subagent) ...[
                  const SizedBox(width: 8),
                  _Count(icon: Icons.chevron_right, label: 'entrar'),
                ],
                if (node.backCalls > 0) ...[
                  const SizedBox(width: 8),
                  _Count(
                    icon: Icons.reply,
                    label: '${node.backCalls}',
                    color: kMapConsultColor,
                    // Se toca y abre las idas y vueltas, en orden. El cuadro
                    // del lienzo muestra la última; las anteriores viven acá
                    // detrás, que es lo que este número promete desde que
                    // existe.
                    onTap: onOpenConsults,
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
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _clock(Duration elapsed) {
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// La marca del nodo: dos letras sobre el color del miembro.
///
/// Letras y no el mismo icono para todos, que es lo que había: con cinco
/// nodos del mismo workflow, cinco robots idénticos hacían que la fila
/// entera se leyera igual y hubiera que leer el nombre de cada uno para
/// saber quién es quién. El color ya los separa; las letras los nombran.
class _Glyph extends StatelessWidget {
  const _Glyph({required this.node, required this.accent});

  final MapNode node;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Vos, el fin y las actividades que cuelgan del tronco llevan un icono
    // semántico. Una consulta sí tiene perfil/color, pero el reply deja claro
    // que no es otro paso del workflow.
    final icon = switch (node.kind) {
      MapNodeKind.you => Icons.person_outline,
      MapNodeKind.end => Icons.flag_outlined,
      MapNodeKind.consultation => Icons.reply,
      MapNodeKind.subagent => Icons.account_tree_outlined,
      _ => null,
    };

    if (icon != null) {
      final ghost = node.kind == MapNodeKind.subagent;
      final color = switch (node.kind) {
        MapNodeKind.you => scheme.primary,
        MapNodeKind.consultation => kMapConsultColor,
        MapNodeKind.subagent => scheme.outline, // el `.av.ghost` del mockup
        _ => scheme.outline,
      };
      final glyph = Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: node.kind == MapNodeKind.you
              ? color.withValues(alpha: 0.18)
              : null,
          borderRadius: BorderRadius.circular(6),
          border: node.kind == MapNodeKind.you || ghost
              ? null
              : Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Icon(icon, size: 13, color: color),
      );
      return ghost ? _GhostBorder(color: color, child: glyph) : glyph;
    }

    final idle = node.state == MapNodeState.idle;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: idle ? accent.withValues(alpha: 0.35) : accent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        initialsOf(node.label),
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: scheme.surface,
        ),
      ),
    );
  }
}

/// Las dos letras de un handle.
///
/// Del ÚLTIMO tramo y no del primero: una familia de agentes se nombra por
/// un prefijo común —`i18n-analista`, `i18n-auditor`, `i18n-traductor`— y
/// las dos primeras letras los dejaba a todos en «i1».
String initialsOf(String handle) {
  final clean = handle.trim().toLowerCase();
  if (clean.isEmpty) return '··';
  final parts = clean
      .split(RegExp(r'[^a-záéíóúñ0-9]+'))
      .where((part) => part.isNotEmpty)
      .toList();
  // Sin ningún tramo con letras no hay iniciales que sacar: dos puntos
  // dicen «acá va alguien» mejor que dos guiones del nombre crudo.
  if (parts.isEmpty) return '··';
  final last = parts.last;
  return last.length >= 2 ? last.substring(0, 2) : last.padRight(2, '·');
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

    final (label, icon, color, body) = switch ((node.kind, node.state)) {
      (MapNodeKind.consultation, MapNodeState.replying) => (
        'le pidió',
        Icons.reply,
        kMapConsultColor,
        node.nodeInstruction,
      ),
      (MapNodeKind.subagent, MapNodeState.done) => (
        'devolvió',
        Icons.check,
        kMapDelegateColor,
        node.resolved,
      ),
      (MapNodeKind.subagent, MapNodeState.failed) => (
        'cortó',
        Icons.warning_amber_rounded,
        scheme.error,
        node.resolved,
      ),
      (MapNodeKind.subagent, _) => (
        'le pidió',
        Icons.account_tree_outlined,
        kMapDelegateColor,
        node.nodeInstruction,
      ),
      (_, MapNodeState.failed) => (
        'cortó',
        Icons.warning_amber_rounded,
        scheme.error,
        node.resolved,
      ),
      (_, MapNodeState.done) when node.answeredOnly => (
        'contestó',
        Icons.reply,
        kMapConsultColor,
        node.resolved,
      ),
      (_, MapNodeState.done) => (
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

    // El razonamiento plegado vive adentro del cuadro, no en el pie del nodo.
    // «resolvió» lo muestra como atajo a la ficha; el subagente en curso
    // («le pidió») muestra la cola de lo que está razonando AHORA, como el
    // `think-peek` del mockup. «devolvió» y «cortó» no lo llevan.
    final reasoning = node.reasoning.trim();
    final liveSubagent = node.kind == MapNodeKind.subagent &&
        node.state != MapNodeState.done &&
        node.state != MapNodeState.failed;
    final reasoningPeek = liveSubagent
        ? (reasoning.isEmpty ? null : _tailOf(node.reasoning))
        : node.state == MapNodeState.done &&
              !node.answeredOnly &&
              node.kind != MapNodeKind.subagent &&
              reasoning.isNotEmpty
        ? 'razonamiento · ${_reasoningLength(node.reasoning)} · tocar para abrir'
        : null;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        width: MapLayout.resolutionWidth,
        child: MapCalloutBox(
          icon: icon,
          label: label,
          text: body,
          color: color.withValues(alpha: 0.75),
          reasoning: reasoningPeek,
          onTap: onTap,
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

  /// Cuánto ocupa el razonamiento, para el «tocar para abrir». El mockup lo
  /// muestra como `1.2k` / `3.4k`, no como un conteo crudo.
  static String _reasoningLength(String reasoning) {
    final length = reasoning.length;
    if (length < 1000) return '$length';
    return '${(length / 1000).toStringAsFixed(1)}k';
  }
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

/// El icono que parpadea: solo el estado «recibiendo» lo lleva. Es el
/// `@keyframes blink` del mockup —va de 1 a .35 y vuelve— y nada más.
class _BlinkingIcon extends StatefulWidget {
  const _BlinkingIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  State<_BlinkingIcon> createState() => _BlinkingIconState();
}

class _BlinkingIconState extends State<_BlinkingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.35), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 0.35, end: 1.0), weight: 1),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Icon(widget.icon, size: widget.size, color: widget.color),
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

/// El borde punteado del avatar fantasma de un subagente: el `.av.ghost` del
/// mockup usa `border: 1px dashed var(--ink-faint)`, y `BoxDecoration` no
/// tiene modo punteado.
class _GhostBorder extends StatelessWidget {
  const _GhostBorder({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedGlyphRRectPainter(color: color),
      child: child,
    );
  }
}

class _DashedGlyphRRectPainter extends CustomPainter {
  _DashedGlyphRRectPainter({required this.color});

  final Color color;

  static const _dashWidth = 4.0;
  static const _dashGap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
      const Radius.circular(6),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final metric = (Path()..addRRect(rrect)).computeMetrics().first;
    var distance = 0.0;
    while (distance < metric.length) {
      final next = (distance + _dashWidth).clamp(0.0, metric.length);
      canvas.drawPath(metric.extractPath(distance, next), paint);
      distance = next + _dashGap;
    }
  }

  @override
  bool shouldRepaint(_DashedGlyphRRectPainter oldDelegate) =>
      oldDelegate.color != color;
}
