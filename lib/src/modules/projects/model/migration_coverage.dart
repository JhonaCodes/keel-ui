import 'package:flutter/foundation.dart';

enum MigrationCoverageArea {
  model,
  serialization,
  persistence,
  dataMigration,
  callers,
  compatibility,
  tests,
  ui,
}

enum MigrationCoverageStatus { pending, satisfied, notApplicable }

@immutable
class MigrationCoverageItem {
  final MigrationCoverageArea area;
  final MigrationCoverageStatus status;
  final String rationale;

  const MigrationCoverageItem({
    required this.area,
    this.status = MigrationCoverageStatus.pending,
    this.rationale = '',
  });

  MigrationCoverageItem copyWith({
    MigrationCoverageStatus? status,
    String? rationale,
  }) => MigrationCoverageItem(
    area: area,
    status: status ?? this.status,
    rationale: rationale ?? this.rationale,
  );

  Map<String, dynamic> toJson() => {
    'area': area.name,
    'status': status.name,
    'rationale': rationale,
  };

  factory MigrationCoverageItem.fromJson(Map<String, dynamic> json) {
    return MigrationCoverageItem(
      area: MigrationCoverageArea.values.byName(json['area'] as String),
      status: MigrationCoverageStatus.values.byName(
        json['status'] as String? ?? MigrationCoverageStatus.pending.name,
      ),
      rationale: json['rationale'] as String? ?? '',
    );
  }
}
