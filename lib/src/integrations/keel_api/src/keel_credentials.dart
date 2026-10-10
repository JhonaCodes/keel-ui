part of '../keel_api.dart';

/// What keeps a signed-in session across restarts: which server, who signed
/// in, and the refresh token. The access token is never stored.
///
/// Its `toString` names the account and the server and nothing else, so a
/// log line that prints it by accident leaks no token.
@immutable
class KeelCredentials {
  const KeelCredentials({
    required this.origin,
    required this.username,
    required this.refreshToken,
  });

  /// The server origin, `https://<host>`, without a path.
  final String origin;
  final String username;
  final String refreshToken;

  bool get isComplete => origin.isNotEmpty && refreshToken.isNotEmpty;

  factory KeelCredentials.fromJson(Map<String, dynamic> json) =>
      KeelCredentials(
        origin: json['origin'] as String? ?? '',
        username: json['username'] as String? ?? '',
        refreshToken: json['refresh_token'] as String? ?? '',
      );

  /// The stored shape. Only [KeelCredentialsStore] writes it, and only into
  /// its owner-only file.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'origin': origin,
    'username': username,
    'refresh_token': refreshToken,
  };

  KeelCredentials copyWith({
    String? origin,
    String? username,
    String? refreshToken,
  }) => KeelCredentials(
    origin: origin ?? this.origin,
    username: username ?? this.username,
    refreshToken: refreshToken ?? this.refreshToken,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeelCredentials &&
          origin == other.origin &&
          username == other.username &&
          refreshToken == other.refreshToken;

  @override
  int get hashCode => Object.hash(origin, username, refreshToken);

  @override
  String toString() => 'KeelCredentials($username @ $origin)';
}

/// Where [KeelCredentials] live: `keel_api_session.json` in the app-support
/// directory, readable and writable by this user only (0600).
///
/// A dedicated file and not a key of the local database, on purpose:
///
/// - the LMDB file is created with the default umask (readable by others on
///   most machines), and the whole database is loaded into memory and shared
///   by every module, some of which scan it by prefix;
/// - this file is created empty, restricted to the owner and only THEN
///   written, and a store that cannot restrict it refuses to keep the token
///   at all — the person signs in again instead;
/// - it is never part of a backup, and signing out deletes it whole.
class KeelCredentialsStore {
  /// [directory] is resolved from `path_provider` when null; a test points
  /// it at a temporary folder.
  KeelCredentialsStore({this._directory});

  static const String fileName = 'keel_api_session.json';

  /// `rw-------`.
  static const int ownerOnlyMode = 0x180;

  final String? _directory;

  Future<File> _file() async {
    final directory =
        _directory ?? (await getApplicationSupportDirectory()).path;
    return File(p.join(directory, fileName));
  }

  /// The stored session, or null when there is none or it cannot be read.
  Future<KeelCredentials?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final credentials = KeelCredentials.fromJson(decoded);
      return credentials.isComplete ? credentials : null;
    } on FileSystemException catch (error) {
      Log.w('keel_api: the stored session could not be read: ${error.message}');
      return null;
    } on FormatException {
      Log.w('keel_api: the stored session is not readable JSON');
      return null;
    }
  }

  /// Keeps [credentials]; false when this machine refused to keep them
  /// owner-only, in which case nothing was left behind.
  Future<bool> write(KeelCredentials credentials) async {
    File? staging;
    try {
      final target = await _file();
      await target.parent.create(recursive: true);
      staging = File('${target.path}.part');
      if (await staging.exists()) await staging.delete();
      // Empty first: nothing secret exists on disk before the mode is set.
      await staging.create();
      if (!await _restrictToOwner(staging)) {
        await staging.delete();
        Log.e('keel_api: the session file could not be made owner-only');
        return false;
      }
      await staging.writeAsString(
        jsonEncode(credentials.toJson()),
        flush: true,
      );
      // A rename keeps the mode and replaces the old session in one step.
      await staging.rename(target.path);
      return true;
    } on FileSystemException catch (error) {
      Log.e('keel_api: the session could not be stored: ${error.message}');
      if (staging != null && await staging.exists()) await staging.delete();
      return false;
    }
  }

  /// Forgets the stored session.
  Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (error) {
      Log.w(
        'keel_api: the stored session could not be removed: '
        '${error.message}',
      );
    }
  }

  /// `chmod 600`, then checks it took. On Windows the profile's own ACL is
  /// what keeps other users out, and there is no mode to set.
  static Future<bool> _restrictToOwner(File file) async {
    if (Platform.isWindows) return true;
    final result = await Process.run('chmod', ['600', file.path]);
    if (result.exitCode != 0) return false;
    final mode = (await file.stat()).mode & 0x1FF;
    return mode == ownerOnlyMode;
  }
}
