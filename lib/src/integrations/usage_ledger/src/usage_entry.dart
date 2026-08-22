part of '../usage_ledger.dart';

/// Un turno, con lo que costó.
class UsageEntry {
  final String id;
  final DateTime at;

  /// `claude` o `codex`. Guardado como texto y no como enum para que un
  /// motor nuevo no invalide el historial viejo.
  final String provider;

  /// El modelo que condujo el turno, como lo nombró el CLI. Vacío cuando el
  /// motor no lo informa.
  final String model;

  final String profileId;
  final String projectId;
  final String sessionId;

  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheCreationTokens;

  final int durationMs;

  /// Lo que informó el CLI. Ya no se muestra en ningún lado —se sacó de la
  /// UI a propósito— pero se sigue midiendo: sacarlo del dato también
  /// habría cerrado la puerta a volver.
  final double costUsd;

  const UsageEntry({
    required this.id,
    required this.at,
    required this.provider,
    required this.model,
    required this.profileId,
    required this.projectId,
    required this.sessionId,
    required this.inputTokens,
    required this.outputTokens,
    required this.cacheReadTokens,
    required this.cacheCreationTokens,
    required this.durationMs,
    required this.costUsd,
  });

  int get totalTokens =>
      inputTokens + outputTokens + cacheReadTokens + cacheCreationTokens;

  /// El día al que pertenece, sin hora. Es la clave de agrupación.
  DateTime get day => DateTime(at.year, at.month, at.day);

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toIso8601String(),
    'provider': provider,
    'model': model,
    'profileId': profileId,
    'projectId': projectId,
    'sessionId': sessionId,
    'inputTokens': inputTokens,
    'outputTokens': outputTokens,
    'cacheReadTokens': cacheReadTokens,
    'cacheCreationTokens': cacheCreationTokens,
    'durationMs': durationMs,
    'costUsd': costUsd,
  };

  factory UsageEntry.fromJson(Map<String, dynamic> json) => UsageEntry(
    id: json['id'] as String,
    at: DateTime.parse(json['at'] as String),
    provider: json['provider'] as String? ?? '',
    model: json['model'] as String? ?? '',
    profileId: json['profileId'] as String? ?? '',
    projectId: json['projectId'] as String? ?? '',
    sessionId: json['sessionId'] as String? ?? '',
    inputTokens: json['inputTokens'] as int? ?? 0,
    outputTokens: json['outputTokens'] as int? ?? 0,
    cacheReadTokens: json['cacheReadTokens'] as int? ?? 0,
    cacheCreationTokens: json['cacheCreationTokens'] as int? ?? 0,
    durationMs: json['durationMs'] as int? ?? 0,
    costUsd: (json['costUsd'] as num?)?.toDouble() ?? 0,
  );
}

class UsageLedgerState {
  /// Los turnos anotados, del más viejo al más nuevo.
  final List<UsageEntry> entries;

  const UsageLedgerState({this.entries = const []});

  /// Cuándo empezó a medirse de verdad. Es lo que hay que decir al lado de
  /// cualquier total: antes de esa fecha no es que no hubo consumo, es que
  /// no se guardaba.
  DateTime? get since => entries.firstOrNull?.at;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UsageLedgerState && listEquals(entries, other.entries);

  @override
  int get hashCode => Object.hashAll(entries.map((entry) => entry.id));

  @override
  String toString() => 'UsageLedgerState(entries: ${entries.length})';
}

class UsageLedgerRepository {
  static const _prefix = 'usage_';

  Future<List<UsageEntry>> load() async {
    final records = await LocalDatabase.getAllWithPrefix(_prefix);
    final entries = records.map(UsageEntry.fromJson).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    return entries;
  }

  /// Escribe UNA entrada. Nunca reescribe el resto: el ledger es
  /// append-only, y `replaceAllWithPrefix` haría un put por registro en cada
  /// turno.
  Future<void> save(UsageEntry entry) =>
      LocalDatabase.put('$_prefix${entry.id}', entry.toJson());

  Future<void> prune(DateTime cutoff) async {
    final records = await LocalDatabase.entriesWithPrefix(_prefix);
    for (final record in records) {
      final at = DateTime.tryParse(record.data['at'] as String? ?? '');
      if (at != null && at.isBefore(cutoff)) {
        await LocalDatabase.delete(record.key);
      }
    }
  }
}
