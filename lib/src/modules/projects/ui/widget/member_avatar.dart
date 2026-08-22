import 'package:flutter/material.dart';

/// The square badge that stands for one member of a project, tinted with the
/// colour that member holds in the channel. It is the only thing that tells
/// four agents apart at a glance, so the bubble and the live strip must draw
/// it identically — hence one widget instead of a copy in each.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.color, required this.small});

  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final size = small ? 22.0 : 28.0;
    final radius = small ? 7.0 : 9.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(Icons.smart_toy, size: small ? 12 : 15, color: color),
    );
  }
}
