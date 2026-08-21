library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/shared/shared.dart';

part 'src/prompt_log.dart';

/// Deterministic, zero-token detector of "things you keep asking for":
/// every user prompt is logged (normalized), and a greedy Jaccard
/// clustering pass proposes a GLOBAL skill when the same kind of request
/// shows up repeatedly. No model is involved at any point — the suggestion
/// is a fact about frequency, not an opinion.
class PromptInsightsViewModel extends ViewModel<PromptInsightsState> {
  PromptInsightsViewModel() : super(const PromptInsightsState());

  static const _maxLogEntries = 500;
  static const _similarityThreshold = 0.55;
  static const _minClusterSize = 3;
  static const _window = Duration(days: 30);

  PromptInsightsRepository get _repository => PromptInsightsRepository();

  List<PromptLogEntry> _log = const [];

  Future<void>? _ready;
  Future<void> get ready => _ready ??= _loadPersisted();

  @override
  void init() {
    if (_ready == null) updateSilently(const PromptInsightsState());
    unawaited(ready.then((_) => scan()));
  }

  Future<void> _loadPersisted() async {
    try {
      final (log, suggestions) = await _repository.load();
      _log = log;
      updateState(data.copyWith(suggestions: suggestions));
    } catch (error) {
      Log.e('Failed to load prompt insights', error: error);
    }
  }

  /// Logs one user prompt. Fire-and-forget from the send paths — never in
  /// their critical path.
  Future<void> record(String text) async {
    await ready;
    final tokens = normalizePromptTokens(text);
    if (tokens.length < 3) return;

    final entry = PromptLogEntry(
      id: generateUuidV4(),
      text: text.trim(),
      tokens: tokens,
      at: DateTime.now(),
    );
    _log = [..._log, entry];
    // FIFO cap so the log never grows unbounded.
    if (_log.length > _maxLogEntries) {
      _log = _log.sublist(_log.length - _maxLogEntries);
    }
    await _repository.saveLog(_log);
  }

  /// Greedy clustering over the recent window. Emits ONE new suggestion per
  /// cluster signature — dismissed clusters never come back.
  Future<void> scan() async {
    await ready;
    final cutoff = DateTime.now().subtract(_window);
    final recent = _log.where((entry) => entry.at.isAfter(cutoff)).toList();

    final clusters = <List<PromptLogEntry>>[];
    for (final entry in recent) {
      List<PromptLogEntry>? home;
      for (final cluster in clusters) {
        if (_jaccard(cluster.first.tokens, entry.tokens) >=
            _similarityThreshold) {
          home = cluster;
          break;
        }
      }
      (home ?? (clusters..add([])).last).add(entry);
    }

    final knownSignatures = data.suggestions
        .map((suggestion) => suggestion.signature)
        .toSet();
    final fresh = <SkillSuggestion>[];
    for (final cluster in clusters) {
      if (cluster.length < _minClusterSize) continue;
      final signature = _signatureOf(cluster);
      if (!knownSignatures.add(signature)) continue;
      fresh.add(
        SkillSuggestion(
          id: generateUuidV4(),
          signature: signature,
          sampleTexts: cluster.reversed
              .take(3)
              .map((entry) => entry.text)
              .toList(),
          occurrences: cluster.length,
          createdAt: DateTime.now(),
        ),
      );
    }
    if (fresh.isEmpty) return;

    final suggestions = [...data.suggestions, ...fresh];
    updateState(data.copyWith(suggestions: suggestions));
    await _repository.saveSuggestions(suggestions);
  }

  /// Marks a suggestion handled (created or dismissed) — it leaves the
  /// band, and its signature keeps future scans from re-proposing it.
  void resolveSuggestion(String id, {required bool dismissed}) {
    final suggestions = data.suggestions
        .map(
          (suggestion) => suggestion.id == id
              ? suggestion.copyWith(
                  status: dismissed
                      ? SkillSuggestionStatus.dismissed
                      : SkillSuggestionStatus.done,
                )
              : suggestion,
        )
        .toList();
    updateState(data.copyWith(suggestions: suggestions));
    unawaited(_repository.saveSuggestions(suggestions));
  }

  double _jaccard(List<String> a, List<String> b) {
    final setA = a.toSet();
    final setB = b.toSet();
    final union = setA.union(setB).length;
    if (union == 0) return 0;
    return setA.intersection(setB).length / union;
  }

  /// Stable identity of a cluster: its most frequent tokens.
  String _signatureOf(List<PromptLogEntry> cluster) {
    final counts = <String, int>{};
    for (final entry in cluster) {
      for (final token in entry.tokens) {
        counts[token] = (counts[token] ?? 0) + 1;
      }
    }
    final ranked = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return ranked.take(6).map((entry) => entry.key).join('-');
  }
}

mixin PromptInsightsService {
  static final ReactiveNotifier<PromptInsightsViewModel> instance =
      ReactiveNotifier<PromptInsightsViewModel>(
        () => PromptInsightsViewModel(),
      );
}
