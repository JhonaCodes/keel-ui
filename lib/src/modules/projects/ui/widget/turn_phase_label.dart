import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/projects/model/session_live_turn.dart';

/// La línea que late: «pensando…», «escribiendo…», «trabajando…».
///
/// Respira porque los dos primeros estados no producen salida propia — sin
/// movimiento el canal parece congelado mientras el agente en realidad está
/// trabajando.
///
/// Vivía adentro de la tira del chat. Salió a widget propio para que el mapa
/// muestre EXACTAMENTE el mismo indicador en vez de dibujar otro parecido: dos
/// animaciones distintas para el mismo estado se leen como dos estados.
class TurnPhaseLabel extends StatefulWidget {
  const TurnPhaseLabel({
    super.key,
    required this.phase,
    required this.accent,
    this.compact = false,
  });

  final TurnPhase phase;
  final Color accent;

  /// En el mapa el cuadro es chico: el texto se recorta a una palabra y el
  /// icono manda.
  final bool compact;

  @override
  State<TurnPhaseLabel> createState() => _TurnPhaseLabelState();
}

class _TurnPhaseLabelState extends State<TurnPhaseLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static IconData iconFor(TurnPhase phase) => switch (phase) {
    TurnPhase.thinking => Icons.psychology_outlined,
    TurnPhase.writing => Icons.edit_note,
    TurnPhase.working => Icons.bolt_outlined,
  };

  static String labelFor(TurnPhase phase) => switch (phase) {
    TurnPhase.thinking => 'pensando…',
    TurnPhase.writing => 'escribiendo…',
    TurnPhase.working => 'trabajando…',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = widget.compact ? 12.0 : 14.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(opacity: 0.45 + 0.55 * _controller.value, child: child);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconFor(widget.phase), size: size, color: widget.accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              labelFor(widget.phase),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: widget.compact ? 10.5 : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
