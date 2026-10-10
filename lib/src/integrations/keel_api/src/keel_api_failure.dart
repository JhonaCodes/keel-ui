part of '../keel_api.dart';

/// Why a call to keel-api, or the remote work it started, did not succeed.
///
/// The UI words each kind (the three ARB catalogs); the failure itself only
/// carries what the server or the node said, verbatim, in
/// [KeelApiFailure.serverMessage].
enum KeelApiFailureKind {
  /// Nobody is signed in, so nothing was sent.
  notSignedIn,

  /// The server address is not an https origin without a path.
  invalidServer,

  /// 401: wrong username, password or code on sign-in, or a session the
  /// server ended.
  unauthorized,

  /// 403: the session does not open this route.
  forbidden,

  /// 400: the server refused the request; its text names the field.
  badRequest,

  /// 404.
  notFound,

  /// 409.
  conflict,

  /// 429: too many attempts from here; wait [KeelApiFailure.retryAfterSeconds].
  rateLimited,

  /// 5xx.
  server,

  /// No answer at all: no network, a timeout, a bad certificate.
  network,

  /// The server answered something this client cannot read, a redirect
  /// included: the token is never carried to another address.
  unexpected,

  /// No node of the kind the work needs is online.
  noOnlineNode,

  /// The task waited in `todo` and no node took it.
  stalled,

  /// The node took the task and ended it with an error.
  nodeFailed,

  /// The session could not be kept on this machine with owner-only
  /// permissions, so it was not kept at all.
  storage;

  static KeelApiFailureKind fromName(String? name) => values.firstWhere(
    (kind) => kind.name == name,
    orElse: () => KeelApiFailureKind.unexpected,
  );
}

@immutable
class KeelApiFailure {
  const KeelApiFailure({
    required this.kind,
    this.serverMessage,
    this.statusCode,
    this.retryAfterSeconds,
  });

  final KeelApiFailureKind kind;

  /// keel-api's own `error` text, or the error a node reported. Never a
  /// token: nothing secret travels in an error body.
  final String? serverMessage;
  final int? statusCode;
  final int? retryAfterSeconds;

  /// The connection failed, not the session: the same call may work later.
  bool get isTransient => switch (kind) {
    KeelApiFailureKind.network ||
    KeelApiFailureKind.server ||
    KeelApiFailureKind.rateLimited => true,
    KeelApiFailureKind.notSignedIn ||
    KeelApiFailureKind.invalidServer ||
    KeelApiFailureKind.unauthorized ||
    KeelApiFailureKind.forbidden ||
    KeelApiFailureKind.badRequest ||
    KeelApiFailureKind.notFound ||
    KeelApiFailureKind.conflict ||
    KeelApiFailureKind.unexpected ||
    KeelApiFailureKind.noOnlineNode ||
    KeelApiFailureKind.stalled ||
    KeelApiFailureKind.nodeFailed ||
    KeelApiFailureKind.storage => false,
  };

  KeelApiFailure copyWith({
    KeelApiFailureKind? kind,
    String? serverMessage,
    int? statusCode,
    int? retryAfterSeconds,
  }) => KeelApiFailure(
    kind: kind ?? this.kind,
    serverMessage: serverMessage ?? this.serverMessage,
    statusCode: statusCode ?? this.statusCode,
    retryAfterSeconds: retryAfterSeconds ?? this.retryAfterSeconds,
  );

  factory KeelApiFailure.fromJson(Map<String, dynamic> json) => KeelApiFailure(
    kind: KeelApiFailureKind.fromName(json['kind'] as String?),
    serverMessage: json['server_message'] as String?,
    statusCode: KeelJson.decodeInt(json['status_code']),
    retryAfterSeconds: KeelJson.decodeInt(json['retry_after_seconds']),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kind.name,
    'server_message': serverMessage,
    'status_code': statusCode,
    'retry_after_seconds': retryAfterSeconds,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeelApiFailure &&
          kind == other.kind &&
          serverMessage == other.serverMessage &&
          statusCode == other.statusCode &&
          retryAfterSeconds == other.retryAfterSeconds;

  @override
  int get hashCode =>
      Object.hash(kind, serverMessage, statusCode, retryAfterSeconds);

  @override
  String toString() => 'KeelApiFailure(${kind.name}, $statusCode)';
}
