part of '../keel_node.dart';

/// keel-ui as the node a [NodeLink] runs tasks on: every command goes to the
/// session engine over the same `ProjectsStore` the widgets use, and the
/// node shows the sessions of this PC's projects.
///
/// Remote work never takes over the window. No task reaches
/// `WorkspaceViewModel`, so the lens stays where the person left it. The one
/// thing keel-core's [CoreEngine] does move is the project's open session
/// (`Project.activeSessionId`, what the central area draws and the sidebar
/// marks): `session.start` opens the session it creates and
/// `session.message` selects the session it writes to. [run] puts the one
/// the person had open back once the command ran ([_OpenSession]); the turn
/// is not affected, because the engine names its session before that.
///
/// Work that names no workflow goes to this PC's Keel AI ([delegate]); while
/// it is not running, such work fails with why. «Aceptar todo» is answered by
/// keel-core's [NodeAutoApprove], and no session is auto-approved without
/// one. The app's projects are not adopted: this PC works on the person's
/// own folders.
final class KeelUiNodeHost extends NodeLinkHost {
  KeelUiNodeHost({
    required this.engine,
    required this._projection,
    this.log,
    this._keelAi = _noKeelAi,
    this._autoApprove,
  });

  /// How the person reads this node's name («Keel (escritorio) se
  /// reinició…»).
  static const String nodeLabel = 'Keel (escritorio)';

  /// What the app shows when its message waits for the session's turn.
  static const String queuedNote =
      'En cola: la sesión lo recibe cuando termine su turno';

  /// The engine every command runs on.
  final CoreEngine engine;
  final KeelProjection Function() _projection;

  /// This PC's Keel AI; null while it is not running.
  final NodeKeelAiChat? Function() _keelAi;

  /// «Aceptar todo» on this PC's sessions; without it, none is.
  final NodeAutoApprove? _autoApprove;

  static NodeKeelAiChat? _noKeelAi() => null;

  @override
  final NodeLinkLog? log;

  ProjectsStore get _store => ProjectsStore.instance;

  @override
  String get label => nodeLabel;

  @override
  KeelProjection get projection => _projection();

  @override
  NodeDelegate? get delegate => switch (_keelAi()) {
    final NodeKeelAiChat chat => NodeKeelAiDelegate(chat),
    null => null,
  };

  @override
  bool autoApproved(String sessionId) =>
      _autoApprove?.autoApproved(sessionId) ?? false;

  @override
  Future<Result<String, String>> setAutoApprove(String sessionId, bool on) =>
      _autoApprove?.setAutoApprove(sessionId, on) ??
      super.setAutoApprove(sessionId, on);

  /// Runs [command] as the app's would run, whoever sent it: [from] names
  /// who did in the log (`the app`, `Keel AI`, `auto-approve`).
  @override
  Future<NodeRunResult> run(
    KeelCommand command, {
    String from = 'the app',
  }) async {
    final open = _OpenSession.before(command, _store.data);
    final Result<Map<String, Object?>, String> result;
    try {
      result = await engine.execute(command);
    } finally {
      open?.restore(_store);
    }
    final NodeRunResult outcome;
    if (result case Ok(:final data)) {
      outcome = (true, null, _answered(command, data));
    } else if (await _deliveredLater(command, result.errorOrNull)) {
      outcome = (
        true,
        null,
        <String, Object?>{
          'sessionId': command.payload['sessionId'],
          'message': queuedNote,
        },
      );
    } else {
      outcome = (
        false,
        result.errorOrNull ?? 'the command did not run',
        const <String, Object?>{},
      );
    }
    final (ok, reason, _) = outcome;
    log?.add(
      'command',
      '${command.type.wire} from $from${ok ? '' : ' — failed: $reason'}',
      level: ok ? 'ok' : 'error',
    );
    return outcome;
  }

  /// The project's name in this PC's catalog, as keel-server's
  /// `ProjectNames` reads it: the app names projects after their repository
  /// (`backend-api`), the catalog by its own names (`aulamas-api`), and the
  /// folder (`~/repos/Aulamas/backend-api`) joins them. The same name or id
  /// first, then the name in any case, then the folder's name; an unknown
  /// name comes back as it is, so the engine says it does not know it.
  @override
  String resolveProject(String name) {
    final projects = _store.data.projects;
    final wanted = name.trim().toLowerCase();
    for (final project in projects) {
      if (project.name == name || project.id == name) return project.name;
    }
    for (final project in projects) {
      if (project.name.toLowerCase() == wanted) return project.name;
    }
    for (final project in projects) {
      final folder = project.workingDirectory.trim();
      if (folder.isNotEmpty && p.basename(folder).toLowerCase() == wanted) {
        return project.name;
      }
    }
    return name;
  }

  /// What the node did, as the app shows it («Sesión cerrada»), when the
  /// engine's answer does not say.
  static Map<String, Object?> _answered(
    KeelCommand command,
    Map<String, Object?> data,
  ) => switch (command.type) {
    KeelCommandType.sessionDelete => {...data, 'message': 'Sesión cerrada'},
    KeelCommandType.sessionCancel => {...data, 'message': 'Sesión detenida'},
    _ => data,
  };

  /// Whether [reason], why the core refused a `session.message`, is the id
  /// of the message it queued: a session in the middle of a turn keeps what
  /// it is sent, as the composer does (keel-core `CoreEngine._message`). On
  /// keel-ui that queue is released: the message is marked to go out by
  /// itself when the turn ends — the composer's «send after this turn» — so
  /// it is delivered, only later, and the person still sees it queued.
  Future<bool> _deliveredLater(KeelCommand command, String? reason) async {
    if (command.type != KeelCommandType.sessionMessage || reason == null) {
      return false;
    }
    final sessionId = command.payload['sessionId'];
    for (final project in _store.data.projects) {
      for (final session in project.sessions) {
        if (session.id != sessionId) continue;
        if (!session.queuedMessages.any((queued) => queued.id == reason)) {
          return false;
        }
        await _store.sendQueuedSessionMessageAfterTurn(
          project.id,
          session.id,
          reason,
        );
        return true;
      }
    }
    return false;
  }
}

/// The session the person had open in the project a remote command may
/// open one in, put back once the command ran — only when the command is
/// what moved it, never over a session the person picked meanwhile (a
/// message to a busy session waits for a disk write while it queues).
final class _OpenSession {
  const _OpenSession({
    required this.projectId,
    required this.sessionId,
    required this.selectedProjectId,
    required this.known,
    this.writesTo,
  });

  final String projectId;

  /// The project's open session before the command; null when it showed
  /// its State.
  final String? sessionId;

  /// The project selected in the sidebar before the command.
  final String? selectedProjectId;

  /// The project's sessions before the command: one that is not among them
  /// is the one `session.start` created.
  final Set<String> known;

  /// The session `session.message` writes to, and selects.
  final String? writesTo;

  /// Only `session.start` (it opens the session it creates) and
  /// `session.message` (it selects the session it writes to) move it: null
  /// for every other command.
  static _OpenSession? before(KeelCommand command, ProjectsState state) {
    final payload = command.payload;
    final Project? project = switch (command.type) {
      KeelCommandType.sessionStart =>
        state.projects
            .where(
              (project) =>
                  project.name == payload['project'] ||
                  project.id == payload['project'],
            )
            .firstOrNull,
      KeelCommandType.sessionMessage =>
        state.projects
            .where(
              (project) => project.sessions.any(
                (session) => session.id == payload['sessionId'],
              ),
            )
            .firstOrNull,
      _ => null,
    };
    if (project == null) return null;
    return _OpenSession(
      projectId: project.id,
      sessionId: project.activeSessionId,
      selectedProjectId: state.selectedProjectId,
      known: {for (final session in project.sessions) session.id},
      writesTo: command.type == KeelCommandType.sessionMessage
          ? '${payload['sessionId']}'
          : null,
    );
  }

  /// Whether [active] is the session the command opened.
  bool _openedByCommand(String active) => switch (writesTo) {
    final String target => active == target,
    null => !known.contains(active),
  };

  void restore(ProjectsStore store) {
    final project = store.data.projects
        .where((project) => project.id == projectId)
        .firstOrNull;
    final active = project?.activeSessionId;
    if (project == null ||
        active == null ||
        active == sessionId ||
        !_openedByCommand(active)) {
      return;
    }
    final open = sessionId;
    if (open != null) {
      // Closed meanwhile: there is nothing to put back.
      if (project.sessions.any((session) => session.id == open)) {
        store.selectSession(projectId, open);
      }
      return;
    }
    // No session was open: back to the project's State. Clearing it selects
    // the project, so the one that was selected is selected again; with none
    // selected, clearing would select this one — the new session stays the
    // project's open one instead.
    final selected = selectedProjectId;
    if (selected == null) return;
    store.showProjectState(projectId);
    if (selected != projectId) store.selectProject(selected);
  }
}
