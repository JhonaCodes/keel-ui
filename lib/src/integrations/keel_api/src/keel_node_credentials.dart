part of '../keel_api.dart';

/// What makes this PC a keel-api node across restarts: the server it
/// enrolled with, its node id, and its own `knt_` token.
///
/// The token is the node's, not the person's: it keeps working while the
/// account's session renews or ends, and only unlinking the node (or
/// enrolling the same id again) revokes it. Its `toString` names the node
/// and the server and nothing else, so a log line that prints it by accident
/// leaks no token.
@immutable
class KeelNodeCredentials {
  const KeelNodeCredentials({
    required this.origin,
    required this.nodeId,
    required this.token,
  });

  /// The server origin, `https://<host>`, without a path.
  final String origin;
  final String nodeId;
  final String token;

  bool get isComplete =>
      origin.isNotEmpty && nodeId.isNotEmpty && token.isNotEmpty;

  /// keel-api's base for the node's own calls, ending in `/`:
  /// `<origin>/v1/keel-bot/`.
  Uri get apiUrl => Uri.parse('$origin${KeelApiPaths.keelBot}/');

  factory KeelNodeCredentials.fromJson(Map<String, dynamic> json) =>
      KeelNodeCredentials(
        origin: json['origin'] as String? ?? '',
        nodeId: json['node_id'] as String? ?? '',
        token: json['token'] as String? ?? '',
      );

  /// The stored shape. Only [KeelNodeCredentialsStore] writes it, and only
  /// into its owner-only file.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'origin': origin,
    'node_id': nodeId,
    'token': token,
  };

  KeelNodeCredentials copyWith({
    String? origin,
    String? nodeId,
    String? token,
  }) => KeelNodeCredentials(
    origin: origin ?? this.origin,
    nodeId: nodeId ?? this.nodeId,
    token: token ?? this.token,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeelNodeCredentials &&
          origin == other.origin &&
          nodeId == other.nodeId &&
          token == other.token;

  @override
  int get hashCode => Object.hash(origin, nodeId, token);

  @override
  String toString() => 'KeelNodeCredentials($nodeId @ $origin)';
}

/// Where [KeelNodeCredentials] live: `keel_node.json` in the app-support
/// directory, readable and writable by this user only (0600), for the same
/// reasons as the account's session file ([KeelCredentialsStore]): never in
/// the local database, never in the vault or a backup, never in a log or a
/// process argument. Disconnecting the node deletes it whole.
class KeelNodeCredentialsStore {
  /// [directory] is resolved from `path_provider` when null; a test points
  /// it at a temporary folder.
  KeelNodeCredentialsStore({this._directory});

  static const String fileName = 'keel_node.json';

  final String? _directory;

  Future<File> _file() async {
    final directory =
        _directory ?? (await getApplicationSupportDirectory()).path;
    return File(p.join(directory, fileName));
  }

  /// The stored node, or null when there is none or it cannot be read.
  Future<KeelNodeCredentials?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final credentials = KeelNodeCredentials.fromJson(decoded);
      return credentials.isComplete ? credentials : null;
    } on FileSystemException catch (error) {
      Log.w('keel_api: the node token could not be read: ${error.message}');
      return null;
    } on FormatException {
      Log.w('keel_api: the node token file is not readable JSON');
      return null;
    }
  }

  /// Keeps [credentials]; false when this machine refused to keep them
  /// owner-only, in which case nothing was left behind.
  Future<bool> write(KeelNodeCredentials credentials) async {
    final written = await OwnerOnlyFile.write(
      await _file(),
      jsonEncode(credentials.toJson()),
    );
    return written.when(
      ok: (_) => true,
      err: (why) {
        Log.e('keel_api: the node token could not be stored: $why');
        return false;
      },
    );
  }

  /// Forgets the stored node.
  Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (error) {
      Log.w('keel_api: the node token could not be removed: ${error.message}');
    }
  }
}
