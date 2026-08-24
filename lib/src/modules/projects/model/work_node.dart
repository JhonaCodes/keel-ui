import 'package:flutter/foundation.dart';

enum WorkNodeKind { triage, impact, implementation, verification, custom }

enum WorkNodeStatus { pending, running, paused, done, blocked }

@immutable
class WorkNode {
  final String id;
  final WorkNodeKind kind;
  final String ownerRole;
  final String ownerProfileId;
  final String title;
  final String instruction;
  final List<String> dependencyIds;
  final WorkNodeStatus status;

  const WorkNode({
    required this.id,
    required this.kind,
    required this.ownerRole,
    this.ownerProfileId = '',
    this.title = '',
    this.instruction = '',
    this.dependencyIds = const [],
    this.status = WorkNodeStatus.pending,
  });

  WorkNode copyWith({
    WorkNodeStatus? status,
    String? ownerRole,
    String? ownerProfileId,
    String? title,
    String? instruction,
    List<String>? dependencyIds,
  }) => WorkNode(
    id: id,
    kind: kind,
    ownerRole: ownerRole ?? this.ownerRole,
    ownerProfileId: ownerProfileId ?? this.ownerProfileId,
    title: title ?? this.title,
    instruction: instruction ?? this.instruction,
    dependencyIds: dependencyIds ?? this.dependencyIds,
    status: status ?? this.status,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'ownerRole': ownerRole,
    'ownerProfileId': ownerProfileId,
    'title': title,
    'instruction': instruction,
    'dependencyIds': dependencyIds,
    'status': status.name,
  };

  factory WorkNode.fromJson(Map<String, dynamic> json) => WorkNode(
    id: json['id'] as String,
    kind: WorkNodeKind.values.byName(json['kind'] as String),
    ownerRole: json['ownerRole'] as String? ?? '',
    ownerProfileId: json['ownerProfileId'] as String? ?? '',
    title: json['title'] as String? ?? '',
    instruction: json['instruction'] as String? ?? '',
    dependencyIds: (json['dependencyIds'] as List?)?.cast<String>() ?? const [],
    status: WorkNodeStatus.values.byName(
      json['status'] as String? ?? WorkNodeStatus.pending.name,
    ),
  );
}
