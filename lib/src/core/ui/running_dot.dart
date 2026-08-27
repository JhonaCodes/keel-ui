import 'package:flutter/material.dart';

/// «Acá hay algo trabajando», con cuántos si son varios.
///
/// Late despacio a propósito: es información, no una alarma. Un punto quieto
/// se confunde con el de selección, y uno que parpadea rápido pide atención
/// que esto no merece — algo corriendo es lo normal en esta app.
///
/// Es uno solo para todo el panel: el encabezado de un grupo, la fila de un
/// proyecto, la de una sesión y la de un requerimiento dicen lo mismo, y si
/// cada una lo dijera distinto habría que aprender tres códigos.
class RunningDot extends StatefulWidget {
  const RunningDot({super.key, this.count = 1, this.size = 6});

  /// Cuántos trabajos. Con uno solo se dibuja el punto sin número: el número
  /// «1» al lado de un punto no agrega nada.
  final int count;

  final double size;

  @override
  State<RunningDot> createState() => _RunningDotState();
}

class _RunningDotState extends State<RunningDot>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0.35).animate(_controller),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        if (widget.count > 1) ...[
          const SizedBox(width: 3),
          Text(
            '${widget.count}',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: scheme.primary,
            ),
          ),
        ],
      ],
    );
  }
}
