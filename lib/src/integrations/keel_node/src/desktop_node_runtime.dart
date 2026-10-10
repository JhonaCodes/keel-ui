part of '../keel_node.dart';

/// This PC as a keel-api node, while it is connected: the session engine
/// ([CoreEngine]) over the person's own projects, the node's projection
/// ([ProjectionHolder]), and the [NodeLink] that takes the app's tasks,
/// reports what the sessions do and sends how the PC is doing.
///
/// Its files live in `<app support>/node_link/`: `tasks.json` (which task
/// follows what, so a restart resumes reporting where it left off) and
/// `event-seq` (the order of the node's events across restarts). The
/// projection is not kept: it starts empty and is rebuilt from the sessions
/// the engine has, whose ids do not change, so every event the link already
/// posted keeps its key.
final class DesktopNodeRuntime {
  DesktopNodeRuntime({required this.credentials, required this.log});

  /// The task types only another kind of node runs, refused here before they
  /// can reach this PC's sessions.
  static const List<NodeTaskHandler> handlers = [ServerOnlyTasks()];

  static const String folderName = 'node_link';
  static const String tasksFileName = 'tasks.json';
  static const String seqFileName = 'event-seq';

  /// The [calls] entry of the task queue (`GET tasks/pending` every five
  /// seconds, and each task's own calls).
  static const String pollEndpoint = 'tasks';

  /// The [calls] entry of the status report (`PUT nodes/{id}/status`, every
  /// 30 seconds), which also keeps the node online for the app.
  static const String statusEndpoint = 'nodes';

  /// Who this node is, where, and its token: read once from its owner-only
  /// file, then from memory on every call.
  final KeelNodeCredentials credentials;

  /// Every call and every task's turn, in memory.
  final NodeMemoryLog log;

  CoreEngine? _engine;
  ProjectionHolder? _holder;
  NodeLink? _link;

  /// What the last call to each keel-api endpoint answered (`tasks`,
  /// `nodes`, `sessions`…); empty while the link is not running.
  Map<String, KeelApiCallRecord> get calls => _link?.client.calls ?? const {};

  /// Starts the engine, the projection and the link, and takes the app's
  /// tasks from now on. Why not, when it could not.
  Future<Result<void, String>> start() async {
    final directory = p.join(
      (await getApplicationSupportDirectory()).path,
      folderName,
    );
    final tasksFile = p.join(directory, tasksFileName);
    try {
      await Directory(directory).create(recursive: true);
      final stamper = await EventStamper.open(
        credentials.nodeId,
        p.join(directory, seqFileName),
      );
      final holder = _holder = ProjectionHolder(stamper: stamper);
      final engine = _engine = CoreEngine();
      holder.follow(engine);
      await engine.start();
      holder.reconcile(engine);
      final client = HttpKeelApiClient(
        apiUrl: credentials.apiUrl,
        nodeId: credentials.nodeId,
        credentials: IssuedNodeToken(() => credentials.token),
        log: log,
      );
      final link = _link = NodeLink(
        client: client,
        host: KeelUiNodeHost(
          engine: engine,
          projection: () => holder.projection,
          log: log,
        ),
        statePath: tasksFile,
        handlers: handlers,
        reporter: NodeStatusReporter(
          client: client,
          snapshot: DesktopNodeSnapshot(
            projection: () => holder.projection,
          ).measure,
          projects: DesktopNodeSnapshot.projects,
        ),
      );
      await link.start();
      link.listenForTasks();
      log.add(
        'node',
        '${KeelUiNodeHost.nodeLabel} up as ${credentials.nodeId}',
        level: 'ok',
      );
      return Ok(null);
    } on FileSystemException catch (error) {
      await stop();
      return Err(error.message);
    } on FormatException catch (error) {
      await stop();
      return Err('$tasksFile is not readable: ${error.message}');
    }
  }

  /// Stops taking tasks, reports what it can in three seconds, and stops
  /// following the engine.
  Future<void> stop() async {
    final link = _link;
    _link = null;
    await link?.stop();
    await _holder?.close();
    _holder = null;
    await _engine?.stop();
    _engine = null;
  }
}
