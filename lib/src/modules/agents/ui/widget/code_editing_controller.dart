import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/agents/model/highlighted_line.dart';

/// A [TextEditingController] that stays fully editable while painting real
/// syntax colors, by overriding [buildTextSpan] instead of swapping in a
/// read-only highlighter widget. [theme] and [language] are mutable so the
/// host can react to a light/dark change — or to the user switching the
/// script's runtime mid-edit — without recreating the controller and losing
/// cursor/selection state.
class CodeEditingController extends TextEditingController {
  CodeEditingController({
    required this.language,
    required this.theme,
    super.text,
  });

  String language;
  Map<String, TextStyle> theme;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final lines = highlightLines(text, language);
    final children = <TextSpan>[];
    for (var i = 0; i < lines.length; i++) {
      children.addAll(renderHighlightedLine(lines[i], theme));
      if (i != lines.length - 1) children.add(const TextSpan(text: '\n'));
    }
    return TextSpan(style: style, children: children);
  }
}
