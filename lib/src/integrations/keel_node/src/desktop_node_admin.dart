part of '../keel_node.dart';

/// This PC as the node commands (`node.*`) see it: it answers `node.log`
/// (its in-memory lines) and `node.projects`, and refuses, with why, what
/// only a server does from the phone — installing a release, restarting,
/// deploys — and the work only keel-server runs (deploys, jobs, launches),
/// so the app shows those actions off instead of hiding them. The commands
/// over the Dokploy apps and the domains (`node.env*`, `node.redeploy`,
/// `node.cloudflare`) are refused by keel-core's default
/// ([NodeAdminHost.managesApps] false, with [NodeAdminHost.noAppsReason]);
/// `node.catalog` and `node.catalog_item` are answered.
final class DesktopNodeAdmin extends NodeAdminHost {
  const DesktopNodeAdmin();

  static const String _updateRefused =
      'Keel en el Mac se actualiza instalando la app nueva en el Mac.';
  static const String _restartRefused =
      'Keel en el Mac se reinicia desde el Mac.';

  @override
  Map<String, String> get refusals => const {
    NodeAdminTasks.typeUpdate: _updateRefused,
    NodeAdminTasks.typeRestart: _restartRefused,
    NodeAdminTasks.typeDeploys: ServerOnlyTasks.reason,
    'deploy.run': ServerOnlyTasks.reason,
    'job.run': ServerOnlyTasks.reason,
    'launch': ServerOnlyTasks.reason,
  };

  /// Nothing starts the app again after it stops.
  @override
  bool get supervised => false;

  /// Never read: this PC refuses `node.update` and `node.restart` before the
  /// handler asks for the version that came back. The status reports the
  /// app's version ([DesktopNodeSnapshot]).
  @override
  String get version => '';

  @override
  NodeLogKeeping get logKeeping =>
      (source: 'memory', capacity: NodeMemoryLog.defaultCapacity);

  @override
  Future<Result<Map<String, Object?>, String>> deploys({
    required bool includeApps,
  }) async => Err(ServerOnlyTasks.reason);

  @override
  Future<Result<NodeInstall, String>> install(
    void Function(String step) report,
  ) async => Err(_updateRefused);

  /// Refused before it is asked ([refusals]).
  @override
  void restart() {}
}
