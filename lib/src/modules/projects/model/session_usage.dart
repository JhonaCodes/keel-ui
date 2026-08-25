import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/modules/projects/model/token_usage.dart';

@immutable
class SessionUsage {
  final int turns;
  final int tokenMeasuredTurns;
  final int costMeasuredTurns;
  final TokenUsage tokens;
  final double reportedCostUsd;
  final int durationMs;
  final int latestContextUsedTokens;
  final int latestContextWindowTokens;
  final Map<String, SessionUsage> byWorkNodeId;
  final Map<String, SessionUsage> byProfileId;
  final Map<String, TokenUsage> cumulativeByProfileId;

  const SessionUsage({
    this.turns = 0,
    this.tokenMeasuredTurns = 0,
    this.costMeasuredTurns = 0,
    this.tokens = const TokenUsage(),
    this.reportedCostUsd = 0,
    this.durationMs = 0,
    this.latestContextUsedTokens = 0,
    this.latestContextWindowTokens = 0,
    this.byWorkNodeId = const {},
    this.byProfileId = const {},
    this.cumulativeByProfileId = const {},
  });

  bool get hasTokenMeasurement => tokenMeasuredTurns > 0;
  bool get hasCompleteTokenMeasurement =>
      turns > 0 && tokenMeasuredTurns == turns;
  bool get hasCostMeasurement => costMeasuredTurns > 0;
  bool get hasCompleteCostMeasurement =>
      turns > 0 && costMeasuredTurns == turns;

  SessionUsage withLatestContext({required int used, required int window}) =>
      SessionUsage(
        turns: turns,
        tokenMeasuredTurns: tokenMeasuredTurns,
        costMeasuredTurns: costMeasuredTurns,
        tokens: tokens,
        reportedCostUsd: reportedCostUsd,
        durationMs: durationMs,
        latestContextUsedTokens: used,
        latestContextWindowTokens: window,
        byWorkNodeId: byWorkNodeId,
        byProfileId: byProfileId,
        cumulativeByProfileId: cumulativeByProfileId,
      );

  SessionUsage recordTurn({
    required String profileId,
    required String? workNodeId,
    required TokenUsage reportedTokens,
    required bool tokensReported,
    required bool usageIsCumulative,
    required double reportedCostUsd,
    required bool costReported,
    required int durationMs,
    required int contextUsedTokens,
    required int contextWindowTokens,
  }) {
    final previous = cumulativeByProfileId[profileId] ?? const TokenUsage();
    final addedTokens = !tokensReported
        ? const TokenUsage()
        : usageIsCumulative
        ? reportedTokens.deltaFrom(previous)
        : reportedTokens;
    final nextCumulative = Map<String, TokenUsage>.from(cumulativeByProfileId);
    if (tokensReported && usageIsCumulative) {
      nextCumulative[profileId] = reportedTokens;
    }

    final turn = SessionUsage(
      turns: 1,
      tokenMeasuredTurns: tokensReported ? 1 : 0,
      costMeasuredTurns: costReported ? 1 : 0,
      tokens: addedTokens,
      reportedCostUsd: costReported ? reportedCostUsd : 0,
      durationMs: durationMs,
      latestContextUsedTokens: contextUsedTokens,
      latestContextWindowTokens: contextWindowTokens,
    );
    final nodeTotals = Map<String, SessionUsage>.from(byWorkNodeId);
    final normalizedNodeId = workNodeId?.trim() ?? '';
    if (normalizedNodeId.isNotEmpty) {
      nodeTotals[normalizedNodeId] =
          (nodeTotals[normalizedNodeId] ?? const SessionUsage())._plus(turn);
    }
    final profileTotals = Map<String, SessionUsage>.from(byProfileId);
    if (profileId.isNotEmpty) {
      profileTotals[profileId] =
          (profileTotals[profileId] ?? const SessionUsage())._plus(turn);
    }

    final total = _plus(turn);
    return SessionUsage(
      turns: total.turns,
      tokenMeasuredTurns: total.tokenMeasuredTurns,
      costMeasuredTurns: total.costMeasuredTurns,
      tokens: total.tokens,
      reportedCostUsd: total.reportedCostUsd,
      durationMs: total.durationMs,
      latestContextUsedTokens: total.latestContextUsedTokens,
      latestContextWindowTokens: total.latestContextWindowTokens,
      byWorkNodeId: nodeTotals,
      byProfileId: profileTotals,
      cumulativeByProfileId: nextCumulative,
    );
  }

  SessionUsage _plus(SessionUsage other) => SessionUsage(
    turns: turns + other.turns,
    tokenMeasuredTurns: tokenMeasuredTurns + other.tokenMeasuredTurns,
    costMeasuredTurns: costMeasuredTurns + other.costMeasuredTurns,
    tokens: tokens + other.tokens,
    reportedCostUsd: reportedCostUsd + other.reportedCostUsd,
    durationMs: durationMs + other.durationMs,
    latestContextUsedTokens: other.latestContextUsedTokens > 0
        ? other.latestContextUsedTokens
        : latestContextUsedTokens,
    latestContextWindowTokens: other.latestContextWindowTokens > 0
        ? other.latestContextWindowTokens
        : latestContextWindowTokens,
  );

  Map<String, dynamic> toJson() => {
    'turns': turns,
    'tokenMeasuredTurns': tokenMeasuredTurns,
    'costMeasuredTurns': costMeasuredTurns,
    'tokens': tokens.toJson(),
    'reportedCostUsd': reportedCostUsd,
    'durationMs': durationMs,
    'latestContextUsedTokens': latestContextUsedTokens,
    'latestContextWindowTokens': latestContextWindowTokens,
    'byWorkNodeId': {
      for (final entry in byWorkNodeId.entries) entry.key: entry.value.toJson(),
    },
    'byProfileId': {
      for (final entry in byProfileId.entries) entry.key: entry.value.toJson(),
    },
    'cumulativeByProfileId': {
      for (final entry in cumulativeByProfileId.entries)
        entry.key: entry.value.toJson(),
    },
  };

  factory SessionUsage.fromJson(Map<String, dynamic> json) => SessionUsage(
    turns: json['turns'] as int? ?? 0,
    tokenMeasuredTurns: json['tokenMeasuredTurns'] as int? ?? 0,
    costMeasuredTurns: json['costMeasuredTurns'] as int? ?? 0,
    tokens: json['tokens'] is Map
        ? TokenUsage.fromJson((json['tokens'] as Map).cast<String, dynamic>())
        : const TokenUsage(),
    reportedCostUsd: (json['reportedCostUsd'] as num?)?.toDouble() ?? 0,
    durationMs: json['durationMs'] as int? ?? 0,
    latestContextUsedTokens: json['latestContextUsedTokens'] as int? ?? 0,
    latestContextWindowTokens: json['latestContextWindowTokens'] as int? ?? 0,
    byWorkNodeId: _usageMap(json['byWorkNodeId']),
    byProfileId: _usageMap(json['byProfileId']),
    cumulativeByProfileId: _tokenMap(json['cumulativeByProfileId']),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionUsage &&
          turns == other.turns &&
          tokenMeasuredTurns == other.tokenMeasuredTurns &&
          costMeasuredTurns == other.costMeasuredTurns &&
          tokens == other.tokens &&
          reportedCostUsd == other.reportedCostUsd &&
          durationMs == other.durationMs &&
          latestContextUsedTokens == other.latestContextUsedTokens &&
          latestContextWindowTokens == other.latestContextWindowTokens &&
          mapEquals(byWorkNodeId, other.byWorkNodeId) &&
          mapEquals(byProfileId, other.byProfileId) &&
          mapEquals(cumulativeByProfileId, other.cumulativeByProfileId);

  @override
  int get hashCode => Object.hash(
    turns,
    tokenMeasuredTurns,
    costMeasuredTurns,
    tokens,
    reportedCostUsd,
    durationMs,
    latestContextUsedTokens,
    latestContextWindowTokens,
    Object.hashAll(byWorkNodeId.entries),
    Object.hashAll(byProfileId.entries),
    Object.hashAll(cumulativeByProfileId.entries),
  );
}

Map<String, SessionUsage> _usageMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      if (entry.key is String && entry.value is Map)
        entry.key as String: SessionUsage.fromJson(
          (entry.value as Map).cast<String, dynamic>(),
        ),
  };
}

Map<String, TokenUsage> _tokenMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      if (entry.key is String && entry.value is Map)
        entry.key as String: TokenUsage.fromJson(
          (entry.value as Map).cast<String, dynamic>(),
        ),
  };
}
