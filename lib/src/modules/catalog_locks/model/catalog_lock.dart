import 'package:flutter/foundation.dart';

/// The same singular kind names exposed by Keel AI's `get_item` tool.
enum CatalogLockKind {
  skill,
  rule,
  tool,
  agent,
  workflow,
  project,
  hook,
  mcpServer(explicitAlias: 'mcp_server'),
  knowledgeBase(explicitAlias: 'knowledge_base'),
  board,
  secret,
  lockRegistry(explicitAlias: 'lock_registry');

  const CatalogLockKind({this.explicitAlias});

  final String? explicitAlias;
  String get alias => explicitAlias ?? name;

  static CatalogLockKind? tryFromAlias(String alias) {
    for (final kind in values) {
      if (kind.alias == alias) return kind;
    }
    return null;
  }
}

/// Boards are only unique inside a project. This is their public lock name
/// everywhere: UI, API and portable backups.
String catalogBoardLockName(String projectName, String boardName) =>
    '$projectName · $boardName';

/// One protected catalog item, identified by the stable `(kind, name)` pair.
class CatalogLock {
  final CatalogLockKind kind;
  final String name;
  final DateTime createdAt;

  const CatalogLock({
    required this.kind,
    required this.name,
    required this.createdAt,
  });

  String get key => '${kind.alias}:$name';

  Map<String, dynamic> toJson() => {
    'kind': kind.alias,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory CatalogLock.fromJson(Map<String, dynamic> json) {
    final kind = CatalogLockKind.tryFromAlias(json['kind'] as String? ?? '');
    if (kind == null) {
      throw ArgumentError.value(
        json['kind'],
        'kind',
        'Tipo de candado inválido',
      );
    }
    return CatalogLock(
      kind: kind,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogLock &&
          kind == other.kind &&
          name == other.name &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(kind, name, createdAt);
}

class CatalogLocksState {
  final List<CatalogLock> locks;

  const CatalogLocksState({this.locks = const []});

  CatalogLocksState copyWith({List<CatalogLock>? locks}) =>
      CatalogLocksState(locks: locks ?? this.locks);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogLocksState && listEquals(locks, other.locks);

  @override
  int get hashCode => Object.hashAll(locks);
}
