part of '../keel_api.dart';

/// Every keel-api path this client calls, relative to the server origin. A
/// path is written once here and nowhere else.
///
/// Taken from keel-api's `docs/account.md` (`/v1/auth`) and
/// `docs/keel-bot.md` (`/v1/keel-bot`).
abstract final class KeelApiPaths {
  // Accounts: signing in from an app.
  static const String auth = '/v1/auth';
  static const String signIn = '$auth/sign-in';
  static const String refresh = '$auth/refresh';
  static const String signOut = '$auth/sign-out';
  static const String me = '$auth/me';

  // The keel-bot module: nodes, the task queue and the sessions report.
  static const String keelBot = '/v1/keel-bot';
  static const String nodes = '$keelBot/nodes';

  /// A person's session may enroll a node too (`kind: desktop` for keel-ui).
  /// The answer carries the node's own `knt_` token, shown once.
  static const String enrollNode = '$nodes/enroll';

  /// One node; a person's `DELETE` unlinks it (`204`) and its token stops
  /// working at once.
  static String node(String id) => '$nodes/${Uri.encodeComponent(id)}';
  static const String tasks = '$keelBot/tasks';
  static String task(String id) => '$tasks/${Uri.encodeComponent(id)}';
  static String taskEvents(String id) => '${task(id)}/events';
  static const String workerSessions = '$keelBot/workers/sessions';
}
