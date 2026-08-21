import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:highlight/highlight.dart' show highlight, Node;

/// One highlighted token: [text] styled by highlight.js class [className]
/// (null means "no specific token class", i.e. plain text).
class HlSpan {
  final String text;
  final String? className;

  const HlSpan(this.text, this.className);
}

/// highlight.js theme keyed by token class name, picked for [brightness] —
/// "estilo VS Code / Android Studio" dark/light code colors.
Map<String, TextStyle> codeHighlightTheme(Brightness brightness) =>
    brightness == Brightness.dark ? atomOneDarkTheme : atomOneLightTheme;

/// Parses [source] as [language] once and splits the resulting token tree
/// into one token list per source line, so diff/editor views can render
/// real syntax colors per line without re-parsing on every rebuild.
List<List<HlSpan>> highlightLines(String source, String language) {
  final lineCount = source.isEmpty ? 1 : '\n'.allMatches(source).length + 1;
  final lines = List.generate(lineCount, (_) => <HlSpan>[]);
  var lineIndex = 0;

  void walk(Node node, String? inheritedClassName) {
    final className = node.className ?? inheritedClassName;
    final value = node.value;
    final children = node.children;
    if (value != null) {
      final parts = value.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].isNotEmpty && lineIndex < lines.length) {
          lines[lineIndex].add(HlSpan(parts[i], className));
        }
        if (i != parts.length - 1 && lineIndex < lines.length - 1) {
          lineIndex++;
        }
      }
    } else if (children != null) {
      for (final child in children) {
        walk(child, className);
      }
    }
  }

  final nodes = highlight.parse(source, language: language).nodes;
  if (nodes != null) {
    for (final node in nodes) {
      walk(node, null);
    }
  }
  return lines;
}

/// Renders one already-computed line of [HlSpan]s as [TextSpan]s under
/// [theme]. Empty lines still need a span so the row keeps its line height.
List<TextSpan> renderHighlightedLine(
  List<HlSpan> spans,
  Map<String, TextStyle> theme,
) {
  if (spans.isEmpty) return const [TextSpan(text: '')];
  return [
    for (final span in spans)
      TextSpan(
        text: span.text,
        style: span.className == null ? null : theme[span.className],
      ),
  ];
}
