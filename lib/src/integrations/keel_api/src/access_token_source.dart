part of '../keel_api.dart';

/// Where [KeelApiClient] gets the bearer token of the signed-in person.
///
/// The account session implements it. The client asks for a token before
/// every signed request, and asks to [renew] once when keel-api answers 401.
abstract interface class AccessTokenSource {
  /// A token that is still valid, renewed first when it is about to expire;
  /// null when nobody is signed in.
  Future<String?> accessToken();

  /// A new token after the server refused the last one; null when the
  /// session is over. Concurrent callers share one renewal, because keel-api
  /// signs a device out when a replaced refresh token comes back.
  Future<String?> renew();
}
