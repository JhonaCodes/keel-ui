/// One row of `GET /v1/keel-bot/nodes`: keel-server on hp-server, a keel-ui
/// desktop, or any other node enrolled with keel-api.
library;

import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/integrations/keel_api/keel_api.dart';

@immutable
class KeelNode {
  const KeelNode({
    required this.id,
    required this.kind,
    required this.label,
    required this.online,
    this.lastSeenAt,
    this.projects = const <String>[],
  });

  /// The node's kind for keel-server.
  static const String serverKind = 'server';

  /// The node's kind for a keel-ui install.
  static const String desktopKind = 'desktop';

  final String id;

  /// [serverKind] or [desktopKind]. A kind a newer server knows and this app
  /// does not is kept as sent instead of guessed.
  final String kind;
  final String label;

  /// `last_seen_at` within 90 s, as keel-api decides it.
  final bool online;
  final DateTime? lastSeenAt;

  /// The names of the projects the node registered, as it last reported
  /// them; empty until it does.
  final List<String> projects;

  bool get isServer => kind == serverKind;

  /// keel-server and keel-ui desktops run sessions and take tasks.
  bool get takesWork => kind == serverKind || kind == desktopKind;

  /// The label the node enrolled with, or its id when it has none.
  String get displayName => label.trim().isEmpty ? id : label;

  /// `keel-server`, `keel-ui`, or the raw kind.
  String get displayKind => switch (kind) {
    serverKind => 'keel-server',
    desktopKind => 'keel-ui',
    final String other => other,
  };

  factory KeelNode.fromJson(Map<String, dynamic> json) => KeelNode(
    id: json['id'] as String? ?? '',
    kind: json['kind'] as String? ?? '',
    label: json['label'] as String? ?? '',
    online: KeelJson.decodeBool(json['online']),
    lastSeenAt: KeelJson.decodeTimestamp(json['last_seen_at']),
    projects: <String>[
      for (final project in json['projects'] as List<Object?>? ?? const [])
        if (project case {'name': final String name} when name.isNotEmpty) name,
    ],
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'kind': kind,
    'label': label,
    'online': online,
    'last_seen_at': lastSeenAt?.toUtc().toIso8601String(),
    'projects': <Map<String, dynamic>>[
      for (final name in projects) <String, dynamic>{'name': name},
    ],
  };

  KeelNode copyWith({
    String? id,
    String? kind,
    String? label,
    bool? online,
    DateTime? lastSeenAt,
    List<String>? projects,
  }) => KeelNode(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    label: label ?? this.label,
    online: online ?? this.online,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    projects: projects ?? this.projects,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeelNode &&
          id == other.id &&
          kind == other.kind &&
          label == other.label &&
          online == other.online &&
          lastSeenAt == other.lastSeenAt &&
          listEquals(projects, other.projects);

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    label,
    online,
    lastSeenAt,
    Object.hashAll(projects),
  );
}

/// What `POST /v1/keel-bot/nodes/enroll` answers: the node and its own
/// `knt_` token, shown once. The token never prints and [toJson] leaves it
/// out — whoever enrolls keeps it where secrets go.
@immutable
class KeelNodeEnrollment {
  const KeelNodeEnrollment({
    required this.id,
    required this.kind,
    required this.label,
    required this.token,
  });

  final String id;
  final String kind;
  final String label;
  final String token;

  factory KeelNodeEnrollment.fromJson(Map<String, dynamic> json) =>
      KeelNodeEnrollment(
        id: json['id'] as String? ?? '',
        kind: json['kind'] as String? ?? '',
        label: json['label'] as String? ?? '',
        token: json['token'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'kind': kind,
    'label': label,
  };

  KeelNodeEnrollment copyWith({
    String? id,
    String? kind,
    String? label,
    String? token,
  }) => KeelNodeEnrollment(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    label: label ?? this.label,
    token: token ?? this.token,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeelNodeEnrollment &&
          id == other.id &&
          kind == other.kind &&
          label == other.label &&
          token == other.token;

  @override
  int get hashCode => Object.hash(id, kind, label, token);

  @override
  String toString() => 'KeelNodeEnrollment($id, $kind)';
}
