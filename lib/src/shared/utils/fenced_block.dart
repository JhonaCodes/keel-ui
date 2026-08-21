part of '../shared.dart';

/// Parses every ` ```&lt;tag&gt; ` fenced block in [text] into a field map. Kept
/// deliberately rigid — `key: value` lines, only [keys] are recognized as
/// field starts — so a caller decides what a block means instead of guessing
/// at prose. A line that doesn't start a recognized key is folded into
/// whichever key came before it, which is what lets a value (e.g. a system
/// prompt) span multiple lines.
List<Map<String, String>> parseFencedBlocks(
  String text, {
  required String tag,
  required Set<String> keys,
}) {
  final pattern = RegExp('```$tag\\s*\\n(.*?)```', dotAll: true);
  final blocks = <Map<String, String>>[];

  for (final match in pattern.allMatches(text)) {
    final body = match.group(1) ?? '';
    final fields = <String, String>{};
    String? current;

    for (final rawLine in body.split('\n')) {
      final separator = rawLine.indexOf(':');
      final candidate = separator == -1
          ? null
          : rawLine.substring(0, separator).trim().toLowerCase();

      if (candidate != null && keys.contains(candidate)) {
        current = candidate;
        fields[current] = rawLine.substring(separator + 1).trim();
        continue;
      }
      if (current == null) continue;
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      fields[current] = '${fields[current]}\n$line'.trim();
    }
    blocks.add(fields);
  }
  return blocks;
}
