part of '../keel_node.dart';

/// Keel AI on this PC, as the Keel app reaches it through keel-api:
/// keel-core's node chat ([NodeKeelAi]) and its orchestration tools
/// ([NodeKeelAiTools]), acting through this node's [KeelUiNodeHost].
///
/// A session it starts is the app's `session.start`: the same command on the
/// same engine ([KeelUiNodeHost.run]), so the session the person had open and
/// the project they had selected stay as they were. Its turns run on
/// keel-core's task runner — each in its own isolate, with the CLI keel-core
/// gives Keel AI — and its tools' token travels in the turn's MCP config
/// file, never in argv.
///
/// Its conversations live in `<app support>/node_link/keel_ai/`, apart from
/// this window's own Keel AI chat. It works in the person's home folder, as
/// keel-ui's agents without a project do.
final class DesktopKeelAi {
  DesktopKeelAi._({
    required this._nodeId,
    required this._host,
    required this._link,
    required this._log,
  });

  /// How this node names where it runs, in Keel AI's prompt and tools.
  static const String place = 'this PC';

  /// Its conversations' folder, inside the node's.
  static const String folderName = 'keel_ai';

  /// Who the commands it runs come from, in the node's log.
  static const String _from = 'Keel AI';

  static const String _linkOff = 'the node link is off on this PC';

  final String _nodeId;
  final KeelUiNodeHost _host;
  final NodeLink? Function() _link;
  final NodeLinkLog _log;

  /// The chat the app's `keelai.*` tasks and the work naming no workflow
  /// reach.
  late final NodeKeelAi chat;
  late final NodeKeelAiTools _tools;

  /// Where Keel AI works: the person's home folder.
  static String get _root =>
      Platform.environment['HOME'] ?? Directory.current.path;

  /// Starts its tools and reads its conversations from [directory], the
  /// node's folder. Why not, when it could not.
  static Future<Result<DesktopKeelAi, String>> start({
    required String directory,
    required String nodeId,
    required KeelUiNodeHost host,
    required NodeLink? Function() link,
    required NodeLinkLog log,
  }) async {
    final keelAi = DesktopKeelAi._(
      nodeId: nodeId,
      host: host,
      link: link,
      log: log,
    );
    try {
      keelAi._tools = await NodeKeelAiTools.start(
        NodeKeelAiActions(
          projectsRoot: () => _root,
          startSession: keelAi._startSession,
          followTask: keelAi._followTask,
          openTask: keelAi._openTask,
          killWork: keelAi._killWork,
          note: (line) => keelAi.chat.note(line),
        ),
        place: place,
      );
    } on SocketException catch (error) {
      return Err('its tools could not listen on this PC: ${error.message}');
    }
    keelAi.chat = NodeKeelAi(
      dir: Directory(p.join(directory, folderName)),
      root: () => _root,
      toolsEntry: () => keelAi._tools.entry,
      onChange: _drawnNowhere,
      prompt: NodeKeelAiPrompt(
        node:
            'keel-ui, the Keel desktop app on the computer '
            '"${Platform.localHostname}"',
        place: place,
      ),
      log: (level, title, detail) =>
          log.add('keelai', title, level: level, detail: detail),
    );
    try {
      await keelAi.chat.load();
    } on FileSystemException catch (error) {
      await keelAi._tools.close();
      return Err(error.message);
    }
    return Ok(keelAi);
  }

  /// Stops the turn in flight and its tools.
  Future<void> stop() async {
    chat.cancel();
    await _tools.close();
  }

  /// Nothing on this PC draws this chat: the app reads it through its
  /// tasks, and the link reports its turn with the node's work on every
  /// pass ([NodeKeelAiWork]).
  static void _drawnNowhere() {}

  /// A session Keel AI starts: the app's `session.start`, as the link runs
  /// it for a task (only what is irreversible asks). One not started for an
  /// app's task gets its own task in keel-api ([_openTaskFor]).
  Future<Result<String, String>> _startSession(
    String project,
    String? workflow,
    String prompt, {
    required bool forAppTask,
  }) async {
    final (ok, reason, data) = await _host.run(
      KeelCommand.create(
        nodeId: _nodeId,
        type: KeelCommandType.sessionStart,
        payload: {
          'project': project,
          'prompt': prompt,
          'per_action_approval': false,
          'workflow': ?workflow,
        },
      ),
      from: _from,
    );
    final sessionId = data['sessionId'];
    if (!ok || sessionId is! String) {
      return Err(reason ?? 'the session did not start');
    }
    if (!forAppTask) _openTaskFor(sessionId, project, prompt);
    return Ok(sessionId);
  }

  /// Opens the task in keel-api that lists session [sessionId] in the app,
  /// behind: the session never waits for keel-api.
  void _openTaskFor(String sessionId, String project, String prompt) {
    final link = _link();
    if (link == null) return;
    unawaited(
      link
          .openTask(sessionId, project: project, prompt: prompt)
          .then<void>(
            (_) {},
            onError: (Object error) => _log.add(
              'task',
              'no task opened for session $sessionId: $error',
              level: 'error',
            ),
          ),
    );
  }

  Future<Result<void, String>> _followTask(
    String taskId,
    String sessionId,
  ) async => await _link()?.followSession(taskId, sessionId) ?? Err(_linkOff);

  /// The task in keel-api that follows session [sessionId], alive on this
  /// PC: the one following it, or one opened for it with what was first
  /// asked of it.
  Future<Result<String, String>> _openTask(String sessionId) async {
    final link = _link();
    if (link == null) return Err(_linkOff);
    final session = _host.projection.sessions[sessionId];
    if (session == null) return Err('no session $sessionId on this PC');
    if (session.finished) return Err('session $sessionId already ended');
    final asked = session.messages
        .where((message) => message.author == 'user')
        .firstOrNull
        ?.text;
    return link.openTask(
      sessionId,
      project: session.project,
      prompt: asked ?? session.title,
    );
  }

  /// Stops Keel AI's own turn when [id] is how the node reports it, and
  /// closes session [id] otherwise, as the app's «Matar» does.
  Future<Result<String, String>> _killWork(String id) async {
    final stopped = chat.stop(id);
    if (stopped != null) return Ok(stopped);
    final (ok, reason, data) = await _host.run(
      KeelCommand.create(
        nodeId: _nodeId,
        type: KeelCommandType.sessionDelete,
        payload: {'sessionId': id},
      ),
      from: _from,
    );
    return ok
        ? Ok('${data['message'] ?? 'done'}')
        : Err(reason ?? 'not stopped');
  }
}
