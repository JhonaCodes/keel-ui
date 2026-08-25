import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/projects/model/session_usage.dart';
import 'package:keel_ui/src/modules/projects/model/token_usage.dart';

void main() {
  test('un acumulado de Codex se convierte en delta sin contar dos veces', () {
    var usage = const SessionUsage();
    usage = _record(
      usage,
      profileId: 'codex',
      nodeId: 'implementation',
      tokens: const TokenUsage(
        inputTokens: 500,
        outputTokens: 100,
        cacheReadTokens: 1500,
      ),
      cumulative: true,
    );
    usage = _record(
      usage,
      profileId: 'codex',
      nodeId: 'verification',
      tokens: const TokenUsage(
        inputTokens: 700,
        outputTokens: 160,
        cacheReadTokens: 2100,
      ),
      cumulative: true,
    );

    expect(usage.turns, 2);
    expect(
      usage.tokens,
      const TokenUsage(
        inputTokens: 700,
        outputTokens: 160,
        cacheReadTokens: 2100,
      ),
    );
    expect(
      usage.byWorkNodeId['implementation']?.tokens,
      const TokenUsage(
        inputTokens: 500,
        outputTokens: 100,
        cacheReadTokens: 1500,
      ),
    );
    expect(
      usage.byWorkNodeId['verification']?.tokens,
      const TokenUsage(
        inputTokens: 200,
        outputTokens: 60,
        cacheReadTokens: 600,
      ),
    );
  });

  test('cada turno queda atribuido a la sesión, nodo y perfil', () {
    final usage = _record(
      const SessionUsage(),
      profileId: 'implementer',
      nodeId: 'implementation',
      tokens: const TokenUsage(
        inputTokens: 120,
        outputTokens: 80,
        cacheReadTokens: 900,
        cacheCreationTokens: 40,
      ),
      cost: 0.125,
      costReported: true,
      contextUsed: 1060,
      contextWindow: 200000,
    );

    expect(usage.tokens.contextTokens, 1060);
    expect(usage.tokens.totalTokens, 1140);
    expect(usage.reportedCostUsd, 0.125);
    expect(usage.hasCompleteTokenMeasurement, isTrue);
    expect(usage.hasCompleteCostMeasurement, isTrue);
    expect(usage.latestContextUsedTokens, 1060);
    expect(usage.latestContextWindowTokens, 200000);
    expect(usage.byWorkNodeId['implementation']?.tokens, usage.tokens);
    expect(usage.byProfileId['implementer']?.tokens, usage.tokens);
  });

  test('un coste no informado queda ausente, no se interpreta como gratis', () {
    final usage = _record(
      const SessionUsage(),
      profileId: 'deepseek',
      nodeId: 'audit',
      tokens: const TokenUsage(inputTokens: 100, outputTokens: 20),
    );

    expect(usage.reportedCostUsd, 0);
    expect(usage.hasCostMeasurement, isFalse);
    expect(usage.hasCompleteCostMeasurement, isFalse);
  });

  test('la métrica completa sobrevive persistencia y reapertura', () {
    final before = _record(
      const SessionUsage(),
      profileId: 'claude',
      nodeId: 'triage',
      tokens: const TokenUsage(inputTokens: 10, outputTokens: 4),
      cost: 0.01,
      costReported: true,
      contextUsed: 10,
      contextWindow: 1000,
    );

    expect(SessionUsage.fromJson(before.toJson()), before);
  });
}

SessionUsage _record(
  SessionUsage usage, {
  required String profileId,
  required String nodeId,
  required TokenUsage tokens,
  bool cumulative = false,
  double cost = 0,
  bool costReported = false,
  int contextUsed = 0,
  int contextWindow = 0,
}) => usage.recordTurn(
  profileId: profileId,
  workNodeId: nodeId,
  reportedTokens: tokens,
  tokensReported: true,
  usageIsCumulative: cumulative,
  reportedCostUsd: cost,
  costReported: costReported,
  durationMs: 250,
  contextUsedTokens: contextUsed,
  contextWindowTokens: contextWindow,
);
