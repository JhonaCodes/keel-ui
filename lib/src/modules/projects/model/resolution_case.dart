import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/modules/projects/model/resolution_finding.dart';
import 'package:keel_ui/src/modules/projects/model/migration_coverage.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_preflight.dart';
import 'package:keel_ui/src/modules/projects/model/work_node.dart';

enum ResolutionCaseStatus { preflight, active, replanning, blocked, completed }

@immutable
class ResolutionCase {
  final String id;
  final String ownerRole;
  final ResolutionCaseStatus status;
  final int replanCount;
  final int reviewCycleCount;
  final List<WorkNode> nodes;
  final List<ResolutionFinding> findings;
  final List<MigrationCoverageItem> coverage;
  final ResolutionPreflight preflight;

  const ResolutionCase({
    required this.id,
    required this.ownerRole,
    this.status = ResolutionCaseStatus.preflight,
    this.replanCount = 0,
    this.reviewCycleCount = 0,
    this.nodes = const [],
    this.findings = const [],
    this.coverage = const [],
    this.preflight = const ResolutionPreflight(),
  });

  ResolutionCase copyWith({
    String? ownerRole,
    ResolutionCaseStatus? status,
    int? replanCount,
    int? reviewCycleCount,
    List<WorkNode>? nodes,
    List<ResolutionFinding>? findings,
    List<MigrationCoverageItem>? coverage,
    ResolutionPreflight? preflight,
  }) => ResolutionCase(
    id: id,
    ownerRole: ownerRole ?? this.ownerRole,
    status: status ?? this.status,
    replanCount: replanCount ?? this.replanCount,
    reviewCycleCount: reviewCycleCount ?? this.reviewCycleCount,
    nodes: nodes ?? this.nodes,
    findings: findings ?? this.findings,
    coverage: coverage ?? this.coverage,
    preflight: preflight ?? this.preflight,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerRole': ownerRole,
    'status': status.name,
    'replanCount': replanCount,
    'reviewCycleCount': reviewCycleCount,
    'nodes': nodes.map((node) => node.toJson()).toList(),
    'findings': findings.map((finding) => finding.toJson()).toList(),
    'coverage': coverage.map((entry) => entry.toJson()).toList(),
    'preflight': preflight.toJson(),
  };

  factory ResolutionCase.fromJson(Map<String, dynamic> json) => ResolutionCase(
    id: json['id'] as String,
    ownerRole: json['ownerRole'] as String? ?? '',
    status: ResolutionCaseStatus.values.byName(
      json['status'] as String? ?? ResolutionCaseStatus.preflight.name,
    ),
    replanCount: json['replanCount'] as int? ?? 0,
    reviewCycleCount: json['reviewCycleCount'] as int? ?? 0,
    nodes: (json['nodes'] as List? ?? const [])
        .map(
          (entry) => WorkNode.fromJson((entry as Map).cast<String, dynamic>()),
        )
        .toList(),
    findings: (json['findings'] as List? ?? const [])
        .map(
          (entry) => ResolutionFinding.fromJson(
            (entry as Map).cast<String, dynamic>(),
          ),
        )
        .toList(),
    coverage: (json['coverage'] as List? ?? const [])
        .map(
          (entry) => MigrationCoverageItem.fromJson(
            (entry as Map).cast<String, dynamic>(),
          ),
        )
        .toList(),
    preflight: ResolutionPreflight.fromJson(
      (json['preflight'] as Map?)?.cast<String, dynamic>(),
    ),
  );
}
