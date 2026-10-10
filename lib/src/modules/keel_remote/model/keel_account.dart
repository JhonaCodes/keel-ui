/// Who is signed in to the Keel API and from which machine, as keel-api's
/// `/v1/auth` answers it (`docs/account.md`).
library;

import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/integrations/keel_api/keel_api.dart';

@immutable
class KeelAccount {
  const KeelAccount({required this.id, required this.username});

  final String id;
  final String username;

  factory KeelAccount.fromJson(Map<String, dynamic> json) => KeelAccount(
    id: json['id'] as String? ?? '',
    username: json['username'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'username': username,
  };

  KeelAccount copyWith({String? id, String? username}) =>
      KeelAccount(id: id ?? this.id, username: username ?? this.username);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeelAccount && id == other.id && username == other.username;

  @override
  int get hashCode => Object.hash(id, username);
}

/// This machine, as the account knows it: the device it signed in as.
@immutable
class KeelDevice {
  const KeelDevice({
    required this.id,
    required this.name,
    required this.platform,
  });

  final String id;
  final String name;
  final String platform;

  factory KeelDevice.fromJson(Map<String, dynamic> json) => KeelDevice(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    platform: json['platform'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'platform': platform,
  };

  KeelDevice copyWith({String? id, String? name, String? platform}) =>
      KeelDevice(
        id: id ?? this.id,
        name: name ?? this.name,
        platform: platform ?? this.platform,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeelDevice &&
          id == other.id &&
          name == other.name &&
          platform == other.platform;

  @override
  int get hashCode => Object.hash(id, name, platform);
}

/// What a sign-in and a refresh answer. Its tokens never print, and
/// [toJson] leaves them out: only the credentials file keeps the refresh
/// token, and nothing keeps the access token.
@immutable
class KeelSession {
  const KeelSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.account,
    required this.device,
  });

  final String accessToken;
  final String refreshToken;

  /// Seconds the access token works.
  final int expiresIn;
  final KeelAccount account;
  final KeelDevice device;

  factory KeelSession.fromJson(Map<String, dynamic> json) => KeelSession(
    accessToken: json['access_token'] as String? ?? '',
    refreshToken: json['refresh_token'] as String? ?? '',
    expiresIn: KeelJson.decodeInt(json['expires_in']) ?? 0,
    account: KeelAccount.fromJson(
      json['account'] as Map<String, dynamic>? ?? const <String, dynamic>{},
    ),
    device: KeelDevice.fromJson(
      json['device'] as Map<String, dynamic>? ?? const <String, dynamic>{},
    ),
  );

  /// Only what may be shown: the tokens stay out.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'expires_in': expiresIn,
    'account': account.toJson(),
    'device': device.toJson(),
  };

  KeelSession copyWith({
    String? accessToken,
    String? refreshToken,
    int? expiresIn,
    KeelAccount? account,
    KeelDevice? device,
  }) => KeelSession(
    accessToken: accessToken ?? this.accessToken,
    refreshToken: refreshToken ?? this.refreshToken,
    expiresIn: expiresIn ?? this.expiresIn,
    account: account ?? this.account,
    device: device ?? this.device,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeelSession &&
          accessToken == other.accessToken &&
          refreshToken == other.refreshToken &&
          expiresIn == other.expiresIn &&
          account == other.account &&
          device == other.device;

  @override
  int get hashCode =>
      Object.hash(accessToken, refreshToken, expiresIn, account, device);

  @override
  String toString() => 'KeelSession(${account.username}, ${device.name})';
}

/// `POST /v1/auth/sign-in`. The password and the code are sent once and
/// never kept, and they never print.
@immutable
class KeelSignInRequest {
  const KeelSignInRequest({
    required this.username,
    required this.password,
    required this.code,
    required this.deviceName,
    required this.platform,
  });

  final String username;
  final String password;

  /// A fresh code of the account's authenticator.
  final String code;
  final String deviceName;

  /// keel-api's word for it: 1 to 20 lowercase letters or digits.
  final String platform;

  factory KeelSignInRequest.fromJson(Map<String, dynamic> json) {
    final device =
        json['device'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return KeelSignInRequest(
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      code: json['code'] as String? ?? '',
      deviceName: device['name'] as String? ?? '',
      platform: device['platform'] as String? ?? '',
    );
  }

  /// The wire shape keel-api's `SignInRequest` asks for.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'username': username.trim().toLowerCase(),
    'password': password,
    'code': code.replaceAll(' ', ''),
    'device': <String, dynamic>{
      'name': deviceName.trim(),
      'platform': platform,
    },
  };

  KeelSignInRequest copyWith({
    String? username,
    String? password,
    String? code,
    String? deviceName,
    String? platform,
  }) => KeelSignInRequest(
    username: username ?? this.username,
    password: password ?? this.password,
    code: code ?? this.code,
    deviceName: deviceName ?? this.deviceName,
    platform: platform ?? this.platform,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeelSignInRequest &&
          username == other.username &&
          password == other.password &&
          code == other.code &&
          deviceName == other.deviceName &&
          platform == other.platform;

  @override
  int get hashCode =>
      Object.hash(username, password, code, deviceName, platform);

  @override
  String toString() => 'KeelSignInRequest($username, $deviceName)';
}
