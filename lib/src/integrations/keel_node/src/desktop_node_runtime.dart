part of '../keel_node.dart';

/// This PC as a keel-api node, while it is connected: the session engine
/// ([CoreEngine]) over the person's own projects, the node's projection
/// ([ProjectionHolder]), its Keel AI ([DesktopKeelAi]), «Aceptar todo»
/// ([NodeAutoApprove]), and the [NodeLink] that takes the app's tasks,
/// reports what the sessions do and sends how the PC is doing.
///
/// Its files live in `<app support>/node_link/`: `tasks.json` (which task
/// follows what, so a restart resumes reporting where it left off),
/// `event-seq` (the order of the node's events across restarts),
/// `auto-approve.json` (the sessions with «Aceptar todo» on) and `keel_ai/`
/// (Keel AI's conversations). The projection is not kept: it starts empty
/// and is rebuilt from the sessions the engine has, whose ids do not change,
/// so every event the link already posted keeps its key.
final class DesktopNodeRuntime {
  DesktopNodeRuntime({required this.credentials, required this.log});

  /// The task types this PC takes besides the link's own: the ones only
  /// another kind of node runs, refused before they can reach this PC's
  /// sessions, and Keel AI's chat ([keelAi], null while it is not running).
  static List<NodeTaskHandler> handlersFor(NodeKeelAiChat? Function() keelAi) =>
      [const ServerOnlyTasks(), NodeKeelAiTasks(keelAi: keelAi)];

  static const String folderName = 'node_link';
  static const String tasksFileName = 'tasks.json';
  static const String seqFileName = 'event-seq';
  static const String autoApproveFileName = 'auto-approve.json';

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
  NodeAutoApprove? _autoApprove;
  DesktopKeelAi? _keelAi;
  NodeLink? _link;

  /// What the last call to each keel-api endpoint answered (`tasks`,
  /// `nodes`, `sessions`…); empty while the link is not running.
  Map<String, KeelApiCallRecord> get calls => _link?.client.calls ?? const {};

  /// Whether Keel AI runs on this node: the app chats with it, and the work
  /// naming no workflow goes to it.
  bool get keelAiRunning => _keelAi != null;

  /// The sessions still going with «Aceptar todo» on.
  List<({String sessionId, String project, String title})>
  get autoApprovedSessions {
    final autoApprove = _autoApprove;
    final holder = _holder;
    if (autoApprove == null || holder == null) return const [];
    return [
      for (final session in holder.projection.sessions.values)
        if (!session.finished && autoApprove.autoApproved(session.id))
          (
            sessionId: session.id,
            project: session.project,
            title: session.title,
          ),
    ];
  }

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
      // «Aceptar todo» answers through the host, which reads the projection
      // the holder hands it every event of: each needs the other.
      late final ProjectionHolder holder;
      late final KeelUiNodeHost host;
      final autoApprove = _autoApprove = NodeAutoApprove(
        nodeId: credentials.nodeId,
        statePath: p.join(directory, autoApproveFileName),
        projection: () => holder.projection,
        run: (command) => host.run(command, from: 'auto-approve'),
        link: () => _link,
        log: log,
      );
      await autoApprove.load();
      holder = _holder = ProjectionHolder(
        stamper: stamper,
        onEvent: autoApprove.onEvent,
      );
      final engine = _engine = CoreEngine();
      host = KeelUiNodeHost(
        engine: engine,
        projection: () => holder.projection,
        log: log,
        keelAi: () => _keelAi?.chat,
        autoApprove: autoApprove,
      );
      holder.follow(engine);
      await engine.start();
      holder.reconcile(engine);
      final keelAi = await DesktopKeelAi.start(
        directory: directory,
        nodeId: credentials.nodeId,
        host: host,
        link: () => _link,
        log: log,
      );
      switch (keelAi) {
        case Ok(:final data):
          _keelAi = data;
        case Err(:final error):
          // The node runs without it: the app's Keel AI tasks fail with why.
          log.add('keelai', 'Keel AI did not start: $error', level: 'error');
      }
      final client = HttpKeelApiClient(
        apiUrl: credentials.apiUrl,
        nodeId: credentials.nodeId,
        credentials: IssuedNodeToken(() => credentials.token),
        log: log,
      );
      final link = _link = NodeLink(
        client: client,
        host: host,
        statePath: tasksFile,
        handlers: handlersFor(() => _keelAi?.chat),
        work: [NodeKeelAiWork(() => _keelAi?.chat)],
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

  /// Stops taking tasks, reports what it can in three seconds, stops Keel
  /// AI and its tools, and stops following the engine.
  Future<void> stop() async {
    final link = _link;
    _link = null;
    await link?.stop();
    final keelAi = _keelAi;
    _keelAi = null;
    await keelAi?.stop();
    _autoApprove = null;
    await _holder?.close();
    _holder = null;
    await _engine?.stop();
    _engine = null;
  }
}
