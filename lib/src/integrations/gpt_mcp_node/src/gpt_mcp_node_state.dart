part of '../gpt_mcp_node.dart';

/// How the ChatGPT connection of this PC looks right now.
enum GptMcpConnection { notStarted, tokenMissing, off, connecting, connected }

class GptMcpNodeState {
  const GptMcpNodeState({
    this.status,
    this.grants = const [],
    this.requests = const [],
    this.tokenMissing = false,
    this.error,
  });

  final GptMcpNodeStatus? status;
  final List<GptGrant> grants;
  final List<GptAccessRequest> requests;

  /// The relay token secret has no value yet.
  final bool tokenMissing;

  /// The last action that failed, in words for the owner.
  final String? error;

  bool get enabled => status?.enabled ?? false;

  String get chatUrlHint => status?.chatUrlHint ?? '';

  String get relayError => status?.relay.lastError ?? '';

  GptMcpConnection get connection {
    final current = status;
    if (current == null || !current.started) return GptMcpConnection.notStarted;
    if (tokenMissing) return GptMcpConnection.tokenMissing;
    if (!current.enabled) return GptMcpConnection.off;
    return current.relay.connected
        ? GptMcpConnection.connected
        : GptMcpConnection.connecting;
  }

  GptMcpNodeState copyWith({
    GptMcpNodeStatus? status,
    List<GptGrant>? grants,
    List<GptAccessRequest>? requests,
    bool? tokenMissing,
    String? error,
    bool clearError = false,
  }) => GptMcpNodeState(
    status: status ?? this.status,
    grants: grants ?? this.grants,
    requests: requests ?? this.requests,
    tokenMissing: tokenMissing ?? this.tokenMissing,
    error: clearError ? null : (error ?? this.error),
  );

  Map<String, dynamic> toJson() => {
    if (status != null) 'status': status!.toJson(),
    'grants': [for (final grant in grants) grant.toJson()],
    'requests': [for (final request in requests) request.toJson()],
    'tokenMissing': tokenMissing,
    if (error != null) 'error': error,
  };

  factory GptMcpNodeState.fromJson(Map<String, dynamic> json) =>
      GptMcpNodeState(
        status: json['status'] == null
            ? null
            : GptMcpNodeStatus.fromJson(json['status'] as Map<String, dynamic>),
        grants: [
          for (final grant in json['grants'] as List<dynamic>? ?? const [])
            GptGrant.fromJson(grant as Map<String, dynamic>),
        ],
        requests: [
          for (final request in json['requests'] as List<dynamic>? ?? const [])
            GptAccessRequest.fromJson(request as Map<String, dynamic>),
        ],
        tokenMissing: json['tokenMissing'] as bool? ?? false,
        error: json['error'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GptMcpNodeState &&
          other.status == status &&
          listEquals(other.grants, grants) &&
          listEquals(other.requests, requests) &&
          other.tokenMissing == tokenMissing &&
          other.error == error;

  @override
  int get hashCode => Object.hash(
    status,
    Object.hashAll(grants),
    Object.hashAll(requests),
    tokenMissing,
    error,
  );
}
