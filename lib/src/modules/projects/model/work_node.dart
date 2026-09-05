import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/modules/projects/model/turn_outcome_report.dart';

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

  /// Lo que dejó el último turno del nodo, tal como lo declaró el agente.
  /// Es lo que viaja a los nodos que dependen de este.
  final TurnOutcomeReport? output;

  /// Cuántas veces corrió el nodo (reintentos incluidos).
  final int attempts;

  const WorkNode({
    required this.id,
    required this.kind,
    required this.ownerRole,
    this.ownerProfileId = '',
    this.title = '',
    this.instruction = '',
    this.dependencyIds = const [],
    this.status = WorkNodeStatus.pending,
    this.output,
    this.attempts = 0,
  });

  WorkNode copyWith({
    WorkNodeStatus? status,
    String? ownerRole,
    String? ownerProfileId,
    String? title,
    String? instruction,
    List<String>? dependencyIds,
    TurnOutcomeReport? output,
    int? attempts,
  }) => WorkNode(
    id: id,
    kind: kind,
    ownerRole: ownerRole ?? this.ownerRole,
    ownerProfileId: ownerProfileId ?? this.ownerProfileId,
    title: title ?? this.title,
    instruction: instruction ?? this.instruction,
    dependencyIds: dependencyIds ?? this.dependencyIds,
    status: status ?? this.status,
    output: output ?? this.output,
    attempts: attempts ?? this.attempts,
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
    'output': output?.toJson(),
    'attempts': attempts,
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
    output: json['output'] is Map
        ? TurnOutcomeReport.fromJson(
            (json['output'] as Map).cast<String, dynamic>(),
          )
        : null,
    attempts: json['attempts'] as int? ?? 0,
  );
}
