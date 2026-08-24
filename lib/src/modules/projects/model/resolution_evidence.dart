import 'package:flutter/foundation.dart';

enum ResolutionEvidenceSource { compiler, linter, test, contract, review }

@immutable
class ResolutionEvidence {
  final String id;
  final ResolutionEvidenceSource source;
  final String summary;
  final String fingerprint;
  final DateTime createdAt;

  const ResolutionEvidence({
    required this.id,
    required this.source,
    required this.summary,
    required this.fingerprint,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source.name,
    'summary': summary,
    'fingerprint': fingerprint,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ResolutionEvidence.fromJson(Map<String, dynamic> json) {
    return ResolutionEvidence(
      id: json['id'] as String,
      source: ResolutionEvidenceSource.values.byName(
        json['source'] as String? ?? ResolutionEvidenceSource.review.name,
      ),
      summary: json['summary'] as String? ?? '',
      fingerprint: json['fingerprint'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
