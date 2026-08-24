import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/modules/projects/model/resolution_evidence.dart';

enum ResolutionFindingStatus { open, assigned, resolved, blocked }

@immutable
class ResolutionFinding {
  final String id;
  final ResolutionEvidence evidence;
  final String affectedNodeId;
  final String ownerRole;
  final ResolutionFindingStatus status;
  final int replanCount;

  const ResolutionFinding({
    required this.id,
    required this.evidence,
    this.affectedNodeId = '',
    this.ownerRole = '',
    this.status = ResolutionFindingStatus.open,
    this.replanCount = 0,
  });

  ResolutionFinding copyWith({
    String? ownerRole,
    String? affectedNodeId,
    ResolutionFindingStatus? status,
    int? replanCount,
  }) => ResolutionFinding(
    id: id,
    evidence: evidence,
    affectedNodeId: affectedNodeId ?? this.affectedNodeId,
    ownerRole: ownerRole ?? this.ownerRole,
    status: status ?? this.status,
    replanCount: replanCount ?? this.replanCount,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'evidence': evidence.toJson(),
    'affectedNodeId': affectedNodeId,
    'ownerRole': ownerRole,
    'status': status.name,
    'replanCount': replanCount,
  };

  factory ResolutionFinding.fromJson(Map<String, dynamic> json) {
    return ResolutionFinding(
      id: json['id'] as String,
      evidence: ResolutionEvidence.fromJson(
        (json['evidence'] as Map).cast<String, dynamic>(),
      ),
      affectedNodeId: json['affectedNodeId'] as String? ?? '',
      ownerRole: json['ownerRole'] as String? ?? '',
      status: ResolutionFindingStatus.values.byName(
        json['status'] as String? ?? ResolutionFindingStatus.open.name,
      ),
      replanCount: json['replanCount'] as int? ?? 0,
    );
  }
}
