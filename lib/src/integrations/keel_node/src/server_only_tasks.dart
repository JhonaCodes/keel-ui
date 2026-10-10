part of '../keel_node.dart';

/// The task types only keel-server runs — deploys, jobs and tools, launches,
/// Cloudflare proposals — refused on this PC at once, with why. Keel AI's
/// chat (`keelai.*`) is not among them: this PC runs its own
/// ([DesktopKeelAi]).
///
/// Without it they would fall to the link's general path: one that names a
/// workflow would start a session in this PC's project, and the rest would
/// go to Keel AI as work naming no workflow.
final class ServerOnlyTasks extends NodeTaskHandler {
  const ServerOnlyTasks();

  /// What the app shows on such a task.
  static const String reason =
      'Este tipo de tarea solo corre en un servidor keel-server.';

  static const Set<String> _types = {'deploy.run', 'job.run', 'tool.run'};
  static const List<String> _families = ['launch.', 'cloudflare.'];

  @override
  bool handles(String type) =>
      _types.contains(type) || _families.any(type.startsWith);

  @override
  Future<void> take(
    NodeTaskContext ctx,
    String id,
    String type,
    Map<String, Object?> payload,
  ) => ctx.finish(id, failed: true, result: {'error': reason});
}
