part of '../gpt_mcp_node.dart';

/// How the ChatGPT connection of a node looks right now.
enum GptMcpConnection { notStarted, tokenMissing, off, connecting, connected }

/// Which machine the Settings section is managing.
enum GptMcpTarget { pc, server }

/// What the owner can do on a node's GPT MCP, wherever it runs: this PC
/// in process, or the server through keel-api's tasks.
abstract interface class GptMcpNodeActions {
  Future<void> refresh();
  Future<void> setEnabled(bool enabled);

  /// Grants [folder] with [mode], or removes its grant when [mode] is null.
  Future<void> setGrant(String folder, GptAccessMode? mode);
  Future<void> decide(String requestId, GptAccessDecision decision);

  /// Shows the subfolders of [folder] (the base when null).
  Future<void> browse(String? folder);

  /// Creates [folder] (relative to the folder the picker shows, or absolute
  /// inside the base) and grants it [mode].
  Future<void> createFolder(String folder, GptAccessMode mode);
}

class GptMcpNodeState {
  const GptMcpNodeState({
    this.status,
    this.grants = const [],
    this.requests = const [],
    this.tokenMissing = false,
    this.error,
    this.base = '',
    this.browsePath = '',
    this.folders = const [],
    this.busy = false,
  });

  final GptMcpNodeStatus? status;
  final List<GptGrant> grants;
  final List<GptAccessRequest> requests;

  /// The relay token secret has no value yet.
  final bool tokenMissing;

  /// The last action that failed, in words for the owner.
  final String? error;

  /// The folder whose subfolders can be granted.
  final String base;

  /// The folder the picker shows, and its subfolders.
  final String browsePath;
  final List<GptFolderNode> folders;

  /// An action is on its way (the server answers in a few seconds).
  final bool busy;

  bool get enabled => status?.enabled ?? false;

  String get chatUrlHint => status?.chatUrlHint ?? '';

  String get relayError => status?.relay.lastError ?? '';

  /// The picker can go one folder up: it is below the base.
  String? get browseParent =>
      browsePath.isEmpty || browsePath == base || base.isEmpty
      ? null
      : p.dirname(browsePath);

  /// Where a new folder named [name] goes: inside the folder the picker
  /// shows, unless [name] is already absolute.
  String folderPath(String name) => p.isAbsolute(name.trim())
      ? name.trim()
      : p.join(browsePath.isEmpty ? base : browsePath, name.trim());

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
    String? base,
    String? browsePath,
    List<GptFolderNode>? folders,
    bool? busy,
  }) => GptMcpNodeState(
    status: status ?? this.status,
    grants: grants ?? this.grants,
    requests: requests ?? this.requests,
    tokenMissing: tokenMissing ?? this.tokenMissing,
    error: clearError ? null : (error ?? this.error),
    base: base ?? this.base,
    browsePath: browsePath ?? this.browsePath,
    folders: folders ?? this.folders,
    busy: busy ?? this.busy,
  );

  /// Applies a node's state as GPT MCP reports it (`{status, base, grants,
  /// requests}`): what the server's `gpt.*` tasks answer.
  GptMcpNodeState withReport(Map<String, dynamic> report) => copyWith(
    status: report['status'] is Map<String, dynamic>
        ? GptMcpNodeStatus.fromJson(report['status'] as Map<String, dynamic>)
        : null,
    base: report['base'] as String?,
    grants: [
      for (final grant in report['grants'] as List<dynamic>? ?? const [])
        GptGrant.fromJson(grant as Map<String, dynamic>),
    ],
    requests: [
      for (final request in report['requests'] as List<dynamic>? ?? const [])
        GptAccessRequest.fromJson(request as Map<String, dynamic>),
    ],
  );

  Map<String, dynamic> toJson() => {
    if (status != null) 'status': status!.toJson(),
    'grants': [for (final grant in grants) grant.toJson()],
    'requests': [for (final request in requests) request.toJson()],
    'tokenMissing': tokenMissing,
    if (error != null) 'error': error,
    'base': base,
    'browsePath': browsePath,
    'folders': [for (final folder in folders) folder.toJson()],
    'busy': busy,
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
        base: json['base'] as String? ?? '',
        browsePath: json['browsePath'] as String? ?? '',
        folders: [
          for (final folder in json['folders'] as List<dynamic>? ?? const [])
            GptFolderNode.fromJson(folder as Map<String, dynamic>),
        ],
        busy: json['busy'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GptMcpNodeState &&
          other.status == status &&
          listEquals(other.grants, grants) &&
          listEquals(other.requests, requests) &&
          other.tokenMissing == tokenMissing &&
          other.error == error &&
          other.base == base &&
          other.browsePath == browsePath &&
          listEquals(other.folders, folders) &&
          other.busy == busy;

  @override
  int get hashCode => Object.hash(
    status,
    Object.hashAll(grants),
    Object.hashAll(requests),
    tokenMissing,
    error,
    base,
    browsePath,
    Object.hashAll(folders),
    busy,
  );
}
