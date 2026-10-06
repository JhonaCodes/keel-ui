import 'package:flutter/painting.dart';
import 'package:keel_core/modules/agents/model/agent_icon_color_values.dart';

import 'package:keel_core/modules/agents/model/agent.dart';

/// `Agent` stores its icon as an ARGB32 int (`iconColorValue`) so the model
/// can live in `keel_core` without depending on Flutter. The UI wants a real
/// `Color`, so it reads it through this extension instead of the raw int.
extension AgentIconColor on Agent {
  Color get iconColor => Color(iconColorValue);
}

/// The palette as `Color`, for pickers and swatches.
final List<Color> kAgentIconColorPalette = [
  for (final value in kAgentIconColorPaletteValues) Color(value),
];

/// Same selection rule as `nextAgentIconColorValue`, wrapped as `Color` for
/// UI call sites that still work with colors instead of raw ints.
Color nextAgentIconColor(Iterable<Color> usedColors) =>
    Color(nextAgentIconColorValue(usedColors.map((color) => color.toARGB32())));
