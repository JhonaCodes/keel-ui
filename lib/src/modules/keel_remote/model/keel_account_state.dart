import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/integrations/keel_api/keel_api.dart';
import 'package:keel_ui/src/modules/keel_remote/model/keel_account.dart';

enum KeelAccountStatus { signedOut, signingIn, signedIn }

/// What the rail's dot says about the Keel API.
enum KeelConnection {
  /// Never signed in, or signed out on purpose: keel-ui is fully local.
  off,

  /// Signed in; signed requests go out.
  connected,

  /// The server ended the session (or it could not be kept): sign in again.
  ended,
}

/// The account session: whether this machine is signed in to the person's
/// own Keel API, where, and as whom.
@immutable
class KeelAccountState {
  const KeelAccountState({
    this.status = KeelAccountStatus.signedOut,
    this.origin = defaultOrigin,
    this.account,
    this.device,
    this.failure,
  });

  /// What the server field starts with. Any origin of the person's own
  /// keel-api works.
  static const String defaultOrigin = 'https://api.jhonacode.com';

  final KeelAccountStatus status;

  /// The server origin, `https://<host>`.
  final String origin;
  final KeelAccount? account;
  final KeelDevice? device;

  /// Why the last sign-in failed, or why the session ended.
  final KeelApiFailure? failure;

  bool get isSignedIn => status == KeelAccountStatus.signedIn;
  bool get isSigningIn => status == KeelAccountStatus.signingIn;

  KeelConnection get connection => switch (status) {
    KeelAccountStatus.signedIn => KeelConnection.connected,
    KeelAccountStatus.signedOut when failure != null => KeelConnection.ended,
    KeelAccountStatus.signedOut ||
    KeelAccountStatus.signingIn => KeelConnection.off,
  };

  /// The host alone, for the screens.
  String get host => Uri.tryParse(origin)?.host ?? origin;

  String get username => account?.username ?? '';

  KeelAccountState copyWith({
    KeelAccountStatus? status,
    String? origin,
    KeelAccount? account,
    KeelDevice? device,
    KeelApiFailure? failure,
    bool clearFailure = false,
  }) => KeelAccountState(
    status: status ?? this.status,
    origin: origin ?? this.origin,
    account: account ?? this.account,
    device: device ?? this.device,
    failure: clearFailure ? null : (failure ?? this.failure),
  );

  factory KeelAccountState.fromJson(Map<String, dynamic> json) =>
      KeelAccountState(
        status: KeelAccountStatus.values.firstWhere(
          (status) => status.name == json['status'],
          orElse: () => KeelAccountStatus.signedOut,
        ),
        origin: json['origin'] as String? ?? defaultOrigin,
        account: switch (json['account']) {
          final Map<String, dynamic> account => KeelAccount.fromJson(account),
          _ => null,
        },
        device: switch (json['device']) {
          final Map<String, dynamic> device => KeelDevice.fromJson(device),
          _ => null,
        },
        failure: switch (json['failure']) {
          final Map<String, dynamic> failure => KeelApiFailure.fromJson(
            failure,
          ),
          _ => null,
        },
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'status': status.name,
    'origin': origin,
    'account': account?.toJson(),
    'device': device?.toJson(),
    'failure': failure?.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeelAccountState &&
          status == other.status &&
          origin == other.origin &&
          account == other.account &&
          device == other.device &&
          failure == other.failure;

  @override
  int get hashCode => Object.hash(status, origin, account, device, failure);
}
