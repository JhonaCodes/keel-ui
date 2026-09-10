import 'package:flutter/material.dart';

import 'package:keel_ui/src/core/ui/keel_mark.dart';

/// The square badge that stands for one member of a project, tinted with the
/// colour that member holds in the channel. It is the only thing that tells
/// four agents apart at a glance, so the bubble, the live strip and the
/// project's radar must draw it identically — hence one widget instead of a
/// copy in each.
///
/// [size] manda y el resto se deriva: un radio o un icono elegidos aparte
/// terminan desalineando la misma marca según dónde se dibuje.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.color,
    this.size = 28,
    this.isKeelAi = false,
  });

  final Color color;
  final double size;

  /// Keel AI no es un miembro más: es la app hablando. Lleva la marca de Keel
  /// en vez del robot genérico, para que se distinga de un agente cualquiera
  /// sin tener que leer el handle.
  final bool isKeelAi;

  @override
  Widget build(BuildContext context) {
    if (isKeelAi) return KeelMark(size: size);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(Icons.smart_toy, size: size * 0.54, color: color),
    );
  }
}
