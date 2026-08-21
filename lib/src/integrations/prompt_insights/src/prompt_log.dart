part of '../prompt_insights.dart';

const _kStopwords = {
  // es
  'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas', 'de', 'del', 'en',
  'a', 'al', 'y', 'o', 'que', 'como', 'con', 'por', 'para', 'me', 'te', 'se',
  'mi', 'tu', 'su', 'lo', 'le', 'es', 'esta', 'este', 'esto', 'hay', 'si',
  'no', 'ya', 'mas', 'pero', 'porfa', 'favor', 'quiero', 'necesito', 'podes',
  'puedes', 'dame', 'hace', 'hacer', 'haceme', 'hazme',
  // en (los repetidos con es ya están arriba)
  'the', 'an', 'of', 'in', 'on', 'to', 'and', 'or', 'that', 'this',
  'is', 'are', 'be', 'it', 'my', 'your', 'for', 'with', 'please',
  'can', 'you', 'i', 'want', 'need', 'make', 'do',
};

/// Lowercased, de-accented-ish, stopword-free token list — the comparable
/// form of a prompt.
List<String> normalizePromptTokens(String text) {
  final cleaned = text
      .toLowerCase()
      .replaceAll(RegExp(r'[áà]'), 'a')
      .replaceAll(RegExp(r'[éè]'), 'e')
      .replaceAll(RegExp(r'[íì]'), 'i')
      .replaceAll(RegExp(r'[óò]'), 'o')
      .replaceAll(RegExp(r'[úù]'), 'u')
      .replaceAll(RegExp(r'[^a-z0-9ñ\s]'), ' ');
  return cleaned
      .split(RegExp(r'\s+'))
      .where((token) => token.length > 2 && !_kStopwords.contains(token))
      .toList();
}

class PromptLogEntry {
  final String id;
  final String text;
  final List<String> tokens;
  final DateTime at;

  const PromptLogEntry({
    required this.id,
    required this.text,
    required this.tokens,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'tokens': tokens,
    'at': at.toIso8601String(),
  };

  factory PromptLogEntry.fromJson(Map<String, dynamic> json) {
    return PromptLogEntry(
      id: json['id'] as String,
      text: json['text'] as String,
      tokens: (json['tokens'] as List).cast<String>(),
      at: DateTime.parse(json['at'] as String),
    );
  }
}

enum SkillSuggestionStatus { pending, dismissed, done }

class SkillSuggestion {
  final String id;

  /// Cluster identity (top tokens) — a dismissed signature is never
  /// proposed again.
  final String signature;
  final List<String> sampleTexts;
  final int occurrences;
  final SkillSuggestionStatus status;
  final DateTime createdAt;

  const SkillSuggestion({
    required this.id,
    required this.signature,
    required this.sampleTexts,
    required this.occurrences,
    required this.createdAt,
    this.status = SkillSuggestionStatus.pending,
  });

  SkillSuggestion copyWith({SkillSuggestionStatus? status}) {
    return SkillSuggestion(
      id: id,
      signature: signature,
      sampleTexts: sampleTexts,
      occurrences: occurrences,
      createdAt: createdAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'signature': signature,
    'sampleTexts': sampleTexts,
    'occurrences': occurrences,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory SkillSuggestion.fromJson(Map<String, dynamic> json) {
    return SkillSuggestion(
      id: json['id'] as String,
      signature: json['signature'] as String,
      sampleTexts: (json['sampleTexts'] as List).cast<String>(),
      occurrences: json['occurrences'] as int,
      status: SkillSuggestionStatus.values.byName(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkillSuggestion &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          signature == other.signature &&
          listEquals(sampleTexts, other.sampleTexts) &&
          occurrences == other.occurrences &&
          status == other.status &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    signature,
    Object.hashAll(sampleTexts),
    occurrences,
    status,
    createdAt,
  );
}

class PromptInsightsState {
  final List<SkillSuggestion> suggestions;

  const PromptInsightsState({this.suggestions = const []});

  List<SkillSuggestion> get pending => suggestions
      .where((suggestion) => suggestion.status == SkillSuggestionStatus.pending)
      .toList();

  PromptInsightsState copyWith({List<SkillSuggestion>? suggestions}) {
    return PromptInsightsState(suggestions: suggestions ?? this.suggestions);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PromptInsightsState &&
          runtimeType == other.runtimeType &&
          listEquals(suggestions, other.suggestions);

  @override
  int get hashCode => Object.hashAll(suggestions);

  @override
  String toString() =>
      'PromptInsightsState(suggestions: ${suggestions.length})';
}

class PromptInsightsRepository {
  static const _logPrefix = 'promptlog_';
  static const _suggestionPrefix = 'skillsuggestion_';

  Future<(List<PromptLogEntry>, List<SkillSuggestion>)> load() async {
    final logRecords = await LocalDatabase.getAllWithPrefix(_logPrefix);
    final suggestionRecords = await LocalDatabase.getAllWithPrefix(
      _suggestionPrefix,
    );
    final log = logRecords.map(PromptLogEntry.fromJson).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    return (log, suggestionRecords.map(SkillSuggestion.fromJson).toList());
  }

  Future<void> saveLog(List<PromptLogEntry> log) async {
    await LocalDatabase.replaceAllWithPrefix(
      _logPrefix,
      log.map((entry) => entry.toJson()).toList(),
    );
  }

  Future<void> saveSuggestions(List<SkillSuggestion> suggestions) async {
    await LocalDatabase.replaceAllWithPrefix(
      _suggestionPrefix,
      suggestions.map((suggestion) => suggestion.toJson()).toList(),
    );
  }
}
