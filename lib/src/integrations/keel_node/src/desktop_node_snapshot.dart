part of '../keel_node.dart';

/// How this PC is doing, as the node reports it to keel-api when it starts
/// and every 30 s ([NodeStatusReporter]), in the shape the Keel app reads
/// (`kind`, `uptime_sec`, `sessions`, and what the machine tells).
///
/// The machine is read by keel-core's machine integration, with macOS's own
/// commands (`sysctl`, `vm_stat`); where it cannot be read — Linux, or a
/// command that fails — the rest of the status still goes.
final class DesktopNodeSnapshot {
  DesktopNodeSnapshot({required this.projection});

  /// The node's sessions as they are now.
  final KeelProjection Function() projection;

  final DateTime _startedAt = DateTime.now();
  String? _version;

  /// The status as this PC is now.
  Future<Map<String, Object?>> measure() async {
    final sessions = projection().sessions.values;
    return {
      'kind': 'desktop',
      'hostname': Platform.localHostname,
      'platform': Platform.operatingSystem,
      // How long this PC has been a node, not since the machine booted.
      'uptime_sec': DateTime.now().difference(_startedAt).inSeconds,
      'cpu_count': Platform.numberOfProcessors,
      ...await _machine(),
      'sessions': {
        'running': sessions.where((s) => s.status == 'running').length,
        'total': sessions.length,
      },
      'version': ?await _appVersion(),
    };
  }

  /// The projects of this PC's catalog: whether each one's folder exists
  /// here, and the workflows a session in it can run — what the app offers
  /// when it sends this node work.
  static List<NodeProject> projects() {
    final store = ProjectsStore.instance;
    return [
      for (final project in store.data.projects)
        (
          name: project.name,
          hasFolder:
              project.workingDirectory.isNotEmpty &&
              Directory(project.workingDirectory).existsSync(),
          workflows: [
            for (final workflow in store.choosableWorkflowsOf(project))
              workflow.name,
          ],
        ),
    ];
  }

  static Future<Map<String, Object?>> _machine() async {
    try {
      final machine = await readMachineState();
      if (machine.memoryTotalBytes == 0) return const {};
      final totalKb = machine.memoryTotalBytes ~/ 1024;
      return {
        'load': [machine.load],
        'mem_total_kb': totalKb,
        'mem_available_kb': totalKb - machine.memoryUsedBytes ~/ 1024,
      };
    } on ProcessException catch (error) {
      Log.d('keel_node: the machine could not be read: ${error.message}');
      return const {};
    }
  }

  Future<String?> _appVersion() async {
    final known = _version;
    if (known != null) return known;
    try {
      final info = await PackageInfo.fromPlatform();
      return _version = '${info.version}+${info.buildNumber}';
    } on Exception catch (error) {
      Log.d('keel_node: the app version could not be read: $error');
      return null;
    }
  }
}
