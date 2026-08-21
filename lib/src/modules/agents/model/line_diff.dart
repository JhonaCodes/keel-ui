enum LineDiffType { unchanged, added, removed }

class DiffLine {
  final LineDiffType type;
  final String content;

  const DiffLine(this.type, this.content);
}

const kMaxDiffLines = 1500;

/// Line-level LCS diff between [before] and [after].
/// Returns null when either side is too large to diff without a noticeable
/// UI stall — callers should fall back to a plain (non-diffed) view.
List<DiffLine>? computeLineDiff(String before, String after) {
  if (before == after) {
    return [
      for (final line in after.split('\n'))
        DiffLine(LineDiffType.unchanged, line),
    ];
  }

  final a = before.isEmpty ? const <String>[] : before.split('\n');
  final b = after.isEmpty ? const <String>[] : after.split('\n');
  if (a.length > kMaxDiffLines || b.length > kMaxDiffLines) return null;

  final n = a.length;
  final m = b.length;
  final dp = List.generate(n + 1, (_) => List.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      dp[i][j] = a[i] == b[j]
          ? dp[i + 1][j + 1] + 1
          : (dp[i + 1][j] > dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1]);
    }
  }

  final result = <DiffLine>[];
  var i = 0;
  var j = 0;
  while (i < n && j < m) {
    if (a[i] == b[j]) {
      result.add(DiffLine(LineDiffType.unchanged, a[i]));
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      result.add(DiffLine(LineDiffType.removed, a[i]));
      i++;
    } else {
      result.add(DiffLine(LineDiffType.added, b[j]));
      j++;
    }
  }
  while (i < n) {
    result.add(DiffLine(LineDiffType.removed, a[i]));
    i++;
  }
  while (j < m) {
    result.add(DiffLine(LineDiffType.added, b[j]));
    j++;
  }
  return result;
}
