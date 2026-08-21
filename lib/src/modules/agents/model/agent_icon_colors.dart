import 'package:flutter/painting.dart';

const List<Color> kAgentIconColorPalette = [
  Color(0xFFEF5350),
  Color(0xFFEC407A),
  Color(0xFFAB47BC),
  Color(0xFF7E57C2),
  Color(0xFF5C6BC0),
  Color(0xFF42A5F5),
  Color(0xFF29B6F6),
  Color(0xFF26C6DA),
  Color(0xFF26A69A),
  Color(0xFF66BB6A),
  Color(0xFF9CCC65),
  Color(0xFFD4E157),
  Color(0xFFFFCA28),
  Color(0xFFFFA726),
  Color(0xFFFF7043),
  Color(0xFF8D6E63),
];

Color nextAgentIconColor(Iterable<Color> usedColors) {
  final used = usedColors.toSet();
  for (final color in kAgentIconColorPalette) {
    if (!used.contains(color)) return color;
  }

  // Palette exhausted: keep generating distinct colors forever by walking
  // the golden angle around the hue wheel — never repeats, unlike a modulo
  // wrap back into the fixed palette.
  var index = used.length;
  Color candidate;
  do {
    final hue = (index * 137.508) % 360;
    candidate = HSLColor.fromAHSL(1.0, hue, 0.55, 0.55).toColor();
    index++;
  } while (used.contains(candidate));
  return candidate;
}
