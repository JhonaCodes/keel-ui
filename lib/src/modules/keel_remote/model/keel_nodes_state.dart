import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/integrations/keel_api/keel_api.dart';
import 'package:keel_ui/src/modules/keel_remote/model/keel_node.dart';

/// Every node enrolled with the Keel API, as last read.
@immutable
class KeelNodesState {
  const KeelNodesState({
    this.nodes = const <KeelNode>[],
    this.loading = false,
    this.failure,
  });

  final List<KeelNode> nodes;
  final bool loading;

  /// The last read that failed; the nodes on screen stay.
  final KeelApiFailure? failure;

  /// The nodes online now that take work: where a new task may go.
  List<KeelNode> get onlineWorkers => nodes
      .where((node) => node.online && node.takesWork)
      .toList(growable: false);

  /// The keel-server nodes online now: the only ones with a Keel AI to talk
  /// to.
  List<KeelNode> get onlineServers => nodes
      .where((node) => node.online && node.isServer)
      .toList(growable: false);

  /// The node [id] names; null for none, or one keel-api does not list.
  KeelNode? byId(String? id) =>
      id == null ? null : nodes.where((node) => node.id == id).firstOrNull;

  /// Whether [id] names a node online now that takes work.
  bool isOnlineWorker(String? id) => onlineWorkers.any((node) => node.id == id);

  KeelNodesState copyWith({
    List<KeelNode>? nodes,
    bool? loading,
    KeelApiFailure? failure,
    bool clearFailure = false,
  }) => KeelNodesState(
    nodes: nodes ?? this.nodes,
    loading: loading ?? this.loading,
    failure: clearFailure ? null : (failure ?? this.failure),
  );

  factory KeelNodesState.fromJson(Map<String, dynamic> json) => KeelNodesState(
    nodes: <KeelNode>[
      for (final row in json['nodes'] as List<Object?>? ?? const [])
        if (row is Map<String, dynamic>) KeelNode.fromJson(row),
    ],
    loading: KeelJson.decodeBool(json['loading']),
    failure: switch (json['failure']) {
      final Map<String, dynamic> failure => KeelApiFailure.fromJson(failure),
      _ => null,
    },
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'nodes': nodes.map((node) => node.toJson()).toList(),
    'loading': loading,
    'failure': failure?.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeelNodesState &&
          listEquals(nodes, other.nodes) &&
          loading == other.loading &&
          failure == other.failure;

  @override
  int get hashCode => Object.hash(Object.hashAll(nodes), loading, failure);
}
