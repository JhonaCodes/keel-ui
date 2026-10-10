import 'dart:async';
import 'dart:io';

import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:result_controller/result_controller.dart';

import 'package:keel_ui/src/integrations/keel_api/keel_api.dart';
import 'package:keel_ui/src/modules/keel_remote/model/keel_account.dart';
import 'package:keel_ui/src/modules/keel_remote/model/keel_account_state.dart';
import 'package:keel_ui/src/modules/keel_remote/repository/keel_auth_repository.dart';
import 'package:keel_ui/src/modules/keel_remote/viewmodel/keel_nodes_viewmodel.dart';
import 'package:keel_ui/src/modules/keel_remote/viewmodel/live_sessions_viewmodel.dart';
import 'package:keel_ui/src/modules/keel_remote/viewmodel/remote_task_viewmodel.dart';
import 'package:keel_ui/src/modules/keel_remote/viewmodel/remote_tasks_viewmodel.dart';
import 'package:keel_ui/src/modules/keel_remote/viewmodel/server_chat_viewmodel.dart';

/// The session with the person's own Keel API, and the tokens every signed
/// request carries.
///
/// The access token lives in memory only; the refresh token in the
/// owner-only credentials file. A renewal is shared by every request waiting
/// for it, because keel-api signs a device out when a refresh token it
/// already replaced comes back.
///
/// The node phase (enrolling this machine as a `desktop` node) starts from
/// here: while [KeelAccountState.isSignedIn], `KeelApiService.client` is
/// pointed at [KeelAccountState.origin] and signs with this session, which is
/// what `KeelNodesRepository.enrollDesktop` needs.
class KeelAccountViewModel extends ViewModel<KeelAccountState>
    implements AccessTokenSource {
  KeelAccountViewModel() : super(const KeelAccountState());

  /// A token is renewed this long before it ends, so no request leaves with
  /// one about to expire.
  static const Duration _margin = Duration(seconds: 30);

  /// keel-api takes device names of 1 to 80 characters.
  static const int _maxDeviceName = 80;

  KeelApiClient get _client => KeelApiService.client.notifier;
  KeelCredentialsStore get _store => KeelApiService.credentials.notifier;
  KeelAuthRepository get _auth => const KeelAuthRepository();

  String? _accessToken;
  DateTime? _accessExpiresAt;
  Future<String?>? _renewing;

  /// Bumped whenever the session changes, so an answer to an older session
  /// never lands on a newer one.
  int _revision = 0;
  bool _restored = false;

  @override
  void init() {}

  /// Reads the stored session once, at startup. A missing or unreadable file
  /// is simply «signed out»: keel-ui works fully local without it.
  Future<void> restore() async {
    if (_restored) return;
    _restored = true;
    final credentials = await _store.read();
    if (credentials == null) return;
    _revision++;
    _client.point(credentials.origin, tokens: this);
    updateState(
      KeelAccountState(
        status: KeelAccountStatus.signedIn,
        origin: credentials.origin,
        account: KeelAccount(id: '', username: credentials.username),
      ),
    );
    // Renews the access token on the way, so a session the server ended
    // shows as ended now and not at the first click.
    unawaited(refreshAccount());
  }

  /// Signs this machine in. Null when it worked.
  Future<KeelApiFailure?> signIn({
    required String origin,
    required String username,
    required String password,
    required String code,
  }) async {
    if (data.isSigningIn) return null;
    final server = KeelApiClient.normalizeOrigin(origin);
    if (!isValidOrigin(server)) {
      const failure = KeelApiFailure(kind: KeelApiFailureKind.invalidServer);
      updateState(data.copyWith(origin: server, failure: failure));
      return failure;
    }

    final revision = ++_revision;
    updateState(
      KeelAccountState(status: KeelAccountStatus.signingIn, origin: server),
    );
    _client.point(server, tokens: this);
    final result = await _auth.signIn(
      KeelSignInRequest(
        username: username,
        password: password,
        code: code,
        deviceName: _deviceName,
        platform: Platform.operatingSystem,
      ),
    );
    if (revision != _revision) return null;

    switch (result) {
      case Err(:final error):
        _client.detach();
        updateState(KeelAccountState(origin: server, failure: error));
        return error;
      case Ok(data: final session):
        final kept = await _store.write(
          KeelCredentials(
            origin: server,
            username: session.account.username,
            refreshToken: session.refreshToken,
          ),
        );
        if (!kept) {
          // A session that cannot be kept owner-only is not kept at all.
          _keep(session);
          await _auth.signOut();
          return _end(const KeelApiFailure(kind: KeelApiFailureKind.storage));
        }
        _keep(session);
        updateState(
          KeelAccountState(
            status: KeelAccountStatus.signedIn,
            origin: server,
            account: session.account,
            device: session.device,
          ),
        );
        return null;
    }
    return null;
  }

  /// Signs this machine out, on the server too when it can be reached.
  Future<void> signOut() async {
    if (data.isSignedIn) {
      final signedOut = await _auth.signOut();
      signedOut.whenError(
        (failure) => Log.w('keel_api: sign-out not confirmed: $failure'),
      );
    }
    await _end(null);
  }

  /// Reads who is signed in and as which device.
  Future<void> refreshAccount() async {
    if (!data.isSignedIn) return;
    final revision = _revision;
    final result = await _auth.me();
    if (revision != _revision || !data.isSignedIn) return;
    result.when(
      ok: (me) => transformState(
        (state) => state.copyWith(account: me.$1, device: me.$2),
      ),
      err: (failure) => Log.w('keel_api: account not read: $failure'),
    );
  }

  /// An https origin with a host and no path; plain http only for a server
  /// on this machine.
  static bool isValidOrigin(String origin) {
    final uri = Uri.tryParse(origin);
    if (uri == null || uri.host.isEmpty) return false;
    if (uri.path.isNotEmpty && uri.path != '/') return false;
    if (uri.hasQuery || uri.hasFragment) return false;
    return switch (uri.scheme) {
      'https' => true,
      'http' => uri.host == 'localhost' || uri.host == '127.0.0.1',
      _ => false,
    };
  }

  @override
  Future<String?> accessToken() async {
    final revision = _revision;
    final token = _accessToken;
    final until = _accessExpiresAt;
    // Ending a session clears the token, so one in memory is always this
    // session's — even mid sign-in, when a session that could not be kept
    // is signed out again.
    if (token != null &&
        until != null &&
        DateTime.now().isBefore(until.subtract(_margin))) {
      return token;
    }
    if (!data.isSignedIn) return null;
    final renewed = await renew();
    if (revision != _revision) return null;
    // Without a network the old token goes, so the request reports the
    // network instead of an empty session.
    return renewed ?? (data.isSignedIn ? token : null);
  }

  @override
  Future<String?> renew() {
    final running = _renewing;
    if (running != null) return running;
    final next = _renew();
    _renewing = next;
    next.whenComplete(() {
      if (identical(_renewing, next)) _renewing = null;
    });
    return next;
  }

  Future<String?> _renew() async {
    if (!data.isSignedIn) return null;
    final revision = _revision;
    final credentials = await _store.read();
    if (revision != _revision) return null;
    if (credentials == null) {
      await _end(const KeelApiFailure(kind: KeelApiFailureKind.unauthorized));
      return null;
    }
    final result = await _auth.refresh(credentials.refreshToken);
    if (revision != _revision || !data.isSignedIn) return null;
    switch (result) {
      case Err(:final error):
        // A network or server failure keeps the session for the next try.
        if (!error.isTransient) await _end(error);
        return null;
      case Ok(data: final session):
        final kept = await _store.write(
          credentials.copyWith(refreshToken: session.refreshToken),
        );
        if (!kept) {
          await _end(const KeelApiFailure(kind: KeelApiFailureKind.storage));
          return null;
        }
        _keep(session);
        if (data.account != session.account || data.device != session.device) {
          transformState(
            (state) => state.copyWith(
              account: session.account,
              device: session.device,
            ),
          );
        }
        return session.accessToken;
    }
    return null;
  }

  void _keep(KeelSession session) {
    _accessToken = session.accessToken;
    _accessExpiresAt = DateTime.now().add(Duration(seconds: session.expiresIn));
  }

  /// Ends the session here: the file goes, the client points nowhere, and
  /// what the other account showed is forgotten. [why] is null for a
  /// sign-out the person asked for.
  Future<KeelApiFailure?> _end(KeelApiFailure? why) async {
    _revision++;
    _accessToken = null;
    _accessExpiresAt = null;
    _renewing = null;
    await _store.clear();
    _client.detach();
    updateState(KeelAccountState(origin: data.origin, failure: why));
    KeelNodesService.instance.notifier.clear();
    RemoteTasksService.instance.notifier.clear();
    RemoteTaskService.instance.notifier.clear();
    LiveSessionsService.instance.notifier.clear();
    ServerChatService.instance.notifier.clear();
    return why;
  }

  /// This machine as the account will list it.
  static String get _deviceName {
    final name = 'Keel · ${Platform.localHostname}'.trim();
    return name.length <= _maxDeviceName
        ? name
        : name.substring(0, _maxDeviceName);
  }
}

mixin KeelAccountService {
  static final ReactiveNotifier<KeelAccountViewModel> instance =
      ReactiveNotifier<KeelAccountViewModel>(KeelAccountViewModel.new);
}
