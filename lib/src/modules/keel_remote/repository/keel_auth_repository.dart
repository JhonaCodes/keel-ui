/// `/v1/auth`: signing in, renewing, reading who is signed in, signing out
/// (keel-api `docs/account.md`).
library;

import 'package:result_controller/result_controller.dart';

import 'package:keel_ui/src/integrations/keel_api/keel_api.dart';
import 'package:keel_ui/src/modules/keel_remote/model/keel_account.dart';

class KeelAuthRepository {
  const KeelAuthRepository();

  KeelApiClient get _client => KeelApiService.client.notifier;

  /// Unsigned: the credentials are the request.
  Future<Result<KeelSession, KeelApiFailure>> signIn(
    KeelSignInRequest request,
  ) async => (await _client.postObject(
    KeelApiPaths.signIn,
    body: request.toJson(),
    signed: false,
  )).map(KeelSession.fromJson);

  /// Unsigned: the refresh token is the request. Every refresh replaces
  /// both tokens.
  Future<Result<KeelSession, KeelApiFailure>> refresh(
    String refreshToken,
  ) async => (await _client.postObject(
    KeelApiPaths.refresh,
    body: <String, dynamic>{'refresh_token': refreshToken},
    signed: false,
  )).map(KeelSession.fromJson);

  /// The signed-in account and this device.
  Future<Result<(KeelAccount, KeelDevice), KeelApiFailure>> me() async =>
      (await _client.getObject(KeelApiPaths.me)).map(
        (json) => (
          KeelAccount.fromJson(
            json['account'] as Map<String, dynamic>? ??
                const <String, dynamic>{},
          ),
          KeelDevice.fromJson(
            json['device'] as Map<String, dynamic>? ??
                const <String, dynamic>{},
          ),
        ),
      );

  /// Signs this device out on the server.
  Future<Result<bool, KeelApiFailure>> signOut() async =>
      (await _client.send('POST', KeelApiPaths.signOut)).map((_) => true);
}
