import 'package:flutter/foundation.dart';

@immutable
class TokenUsage {
  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheCreationTokens;

  const TokenUsage({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cacheReadTokens = 0,
    this.cacheCreationTokens = 0,
  });

  int get contextTokens => inputTokens + cacheReadTokens + cacheCreationTokens;

  int get totalTokens => contextTokens + outputTokens;

  TokenUsage operator +(TokenUsage other) => TokenUsage(
    inputTokens: inputTokens + other.inputTokens,
    outputTokens: outputTokens + other.outputTokens,
    cacheReadTokens: cacheReadTokens + other.cacheReadTokens,
    cacheCreationTokens: cacheCreationTokens + other.cacheCreationTokens,
  );

  /// Codex reports totals for its whole resumed thread. A monotonic report is
  /// converted to the tokens added since the previous report. If the CLI
  /// thread was recreated and the counters went backwards, the new report is
  /// a fresh baseline and is therefore used whole.
  TokenUsage deltaFrom(TokenUsage previous) {
    final monotonic =
        inputTokens >= previous.inputTokens &&
        outputTokens >= previous.outputTokens &&
        cacheReadTokens >= previous.cacheReadTokens &&
        cacheCreationTokens >= previous.cacheCreationTokens;
    if (!monotonic) return this;
    return TokenUsage(
      inputTokens: inputTokens - previous.inputTokens,
      outputTokens: outputTokens - previous.outputTokens,
      cacheReadTokens: cacheReadTokens - previous.cacheReadTokens,
      cacheCreationTokens: cacheCreationTokens - previous.cacheCreationTokens,
    );
  }

  Map<String, dynamic> toJson() => {
    'inputTokens': inputTokens,
    'outputTokens': outputTokens,
    'cacheReadTokens': cacheReadTokens,
    'cacheCreationTokens': cacheCreationTokens,
  };

  factory TokenUsage.fromJson(Map<String, dynamic> json) => TokenUsage(
    inputTokens: json['inputTokens'] as int? ?? 0,
    outputTokens: json['outputTokens'] as int? ?? 0,
    cacheReadTokens: json['cacheReadTokens'] as int? ?? 0,
    cacheCreationTokens: json['cacheCreationTokens'] as int? ?? 0,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenUsage &&
          inputTokens == other.inputTokens &&
          outputTokens == other.outputTokens &&
          cacheReadTokens == other.cacheReadTokens &&
          cacheCreationTokens == other.cacheCreationTokens;

  @override
  int get hashCode => Object.hash(
    inputTokens,
    outputTokens,
    cacheReadTokens,
    cacheCreationTokens,
  );
}
