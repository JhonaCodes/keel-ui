import 'package:flutter/material.dart';

/// The square badge that stands for one member of a project, tinted with the
/// colour that member holds in the channel. It is the only thing that tells
/// four agents apart at a glance, so the bubble, the live strip and the
/// project's radar must draw it identically — hence one widget instead of a
/// copy in each.
///
/// [size] manda y el resto se deriva: un radio o un icono elegidos aparte
/// terminan desalineando la misma marca según dónde se dibuje.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.color, this.size = 28});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
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
