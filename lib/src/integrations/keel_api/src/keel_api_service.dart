part of '../keel_api.dart';

/// The one client every repository calls, and the one place the session is
/// kept on disk.
///
/// A service mixin rather than a global: exactly one place holds each, and
/// the account session is the only one that points them anywhere.
mixin KeelApiService {
  static final ReactiveNotifier<KeelApiClient> client =
      ReactiveNotifier<KeelApiClient>(KeelApiClient.new);

  static final ReactiveNotifier<KeelCredentialsStore> credentials =
      ReactiveNotifier<KeelCredentialsStore>(KeelCredentialsStore.new);

  /// This PC's own node token, while it is connected as a node.
  static final ReactiveNotifier<KeelNodeCredentialsStore> nodeCredentials =
      ReactiveNotifier<KeelNodeCredentialsStore>(KeelNodeCredentialsStore.new);
}
