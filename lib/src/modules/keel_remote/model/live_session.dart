/// One item a node reports in `GET /v1/keel-bot/workers/sessions`: a
/// session of one of its projects, or other work it reports in the same
/// shape (Keel AI answering, a launch, a deploy, a job, a tool, a clone).
library;

import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/integrations/keel_api/keel_api.dart';

/// What a reported item is. The node names it in `kind`; an older node that
/// sends none is read from the id's prefix.
enum LiveSessionKind {
  session('session'),
  keelAi('keelai'),
  launch('launch'),
  deploy('deploy'),
  job('job'),
  tool('tool'),
  clone('clone'),

  /// A kind this app does not know yet: never a session.
  work('work');

  const LiveSessionKind(this.wire);

  final String wire;

  static const Map<String, LiveSessionKind> _prefixes = {
    'chat-': keelAi,
    'launch:': launch,
    'deploy:': deploy,
    'job:': job,
    'tool:': tool,
    'clone:': clone,
  };

  static LiveSessionKind of({required String sessionId, String? wire}) =>
      switch (wire?.trim()) {
        final String named when named.isNotEmpty =>
          values.where((kind) => kind.wire == named).firstOrNull ?? work,
        _ =>
          _prefixes.entries
                  .where((prefix) => sessionId.startsWith(prefix.key))
                  .firstOrNull
                  ?.value ??
              session,
      };

  /// The id after this kind's prefix (`chat-<conversation>`,
  /// `job:<taskId>`); null for an id without it.
  String? idIn(String sessionId) => switch (_prefixes.entries
      .where((prefix) => prefix.value == this)
      .firstOrNull
      ?.key) {
    final String prefix when sessionId.startsWith(prefix) =>
      sessionId.substring(prefix.length),
    _ => null,
  };
}

/// Where a reported item goes in the list, in this order.
enum LiveSessionGroup { waiting, active, work, finished }

@immutable
class LiveSession {
  const LiveSession({
    required this.nodeId,
    required this.sessionId,
    required this.kind,
    required this.project,
    required this.title,
    required this.status,
    required this.step,
    required this.waitingOnYou,
    required this.costUsd,
    this.autoApprove = false,
    this.taskId,
    this.lastSeen,
  });

  static const Set<String> _finishedStatuses = {'done', 'failed', 'cancelled'};

  final String nodeId;
  final String sessionId;
  final LiveSessionKind kind;
  final String project;
  final String title;

  /// Free text as the node sent it: `running`, `waiting`, `done`…
  final String status;

  /// What it is doing now: a step, or the question it waits on.
  final String step;

  /// A decision or a permission waits for an answer.
  final bool waitingOnYou;

  /// Its node approves the session's permissions by itself.
  final bool autoApprove;
  final double costUsd;

  /// The task that started it, when one did.
  final String? taskId;
  final DateTime? lastSeen;

  bool get isFinished => _finishedStatuses.contains(status);

  LiveSessionGroup get group => switch (kind) {
    _ when isFinished => LiveSessionGroup.finished,
    LiveSessionKind.session when waitingOnYou => LiveSessionGroup.waiting,
    LiveSessionKind.session => LiveSessionGroup.active,
    LiveSessionKind.keelAi ||
    LiveSessionKind.launch ||
    LiveSessionKind.deploy ||
    LiveSessionKind.job ||
    LiveSessionKind.tool ||
    LiveSessionKind.clone ||
    LiveSessionKind.work => LiveSessionGroup.work,
  };

  /// The task this item stands for: the one that started it, or the task a
  /// job or a tool carries in its id.
  String? get followedTaskId =>
      taskId ??
      switch (kind) {
        LiveSessionKind.job || LiveSessionKind.tool => kind.idIn(sessionId),
        LiveSessionKind.session ||
        LiveSessionKind.keelAi ||
        LiveSessionKind.launch ||
        LiveSessionKind.deploy ||
        LiveSessionKind.clone ||
        LiveSessionKind.work => null,
      };

  /// `backend-api › Fix login`, or the project alone.
  String get label {
    final name = project.trim().isEmpty ? sessionId : project;
    return title.trim().isEmpty ? name : '$name › $title';
  }

  factory LiveSession.fromJson(Map<String, dynamic> json) {
    final sessionId = json['session_id'] as String? ?? '';
    return LiveSession(
      nodeId: json['node_id'] as String? ?? '',
      sessionId: sessionId,
      kind: LiveSessionKind.of(
        sessionId: sessionId,
        wire: json['kind'] as String?,
      ),
      project: json['project'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? '',
      step: json['step'] as String? ?? '',
      waitingOnYou: KeelJson.decodeBool(json['waiting_on_you']),
      autoApprove: KeelJson.decodeBool(json['auto_approve']),
      costUsd: (json['cost_usd'] as num?)?.toDouble() ?? 0,
      taskId: KeelJson.decodeText(json['task_id']),
      lastSeen: KeelJson.decodeTimestamp(json['last_seen']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'node_id': nodeId,
    'session_id': sessionId,
    'kind': kind.wire,
    'project': project,
    'title': title,
    'status': status,
    'step': step,
    'waiting_on_you': waitingOnYou,
    'auto_approve': autoApprove,
    'cost_usd': costUsd,
    'task_id': taskId,
    'last_seen': lastSeen?.toUtc().toIso8601String(),
  };

  LiveSession copyWith({
    String? nodeId,
    String? sessionId,
    LiveSessionKind? kind,
    String? project,
    String? title,
    String? status,
    String? step,
    bool? waitingOnYou,
    bool? autoApprove,
    double? costUsd,
    String? taskId,
    DateTime? lastSeen,
  }) => LiveSession(
    nodeId: nodeId ?? this.nodeId,
    sessionId: sessionId ?? this.sessionId,
    kind: kind ?? this.kind,
    project: project ?? this.project,
    title: title ?? this.title,
    status: status ?? this.status,
    step: step ?? this.step,
    waitingOnYou: waitingOnYou ?? this.waitingOnYou,
    autoApprove: autoApprove ?? this.autoApprove,
    costUsd: costUsd ?? this.costUsd,
    taskId: taskId ?? this.taskId,
    lastSeen: lastSeen ?? this.lastSeen,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiveSession &&
          nodeId == other.nodeId &&
          sessionId == other.sessionId &&
          kind == other.kind &&
          project == other.project &&
          title == other.title &&
          status == other.status &&
          step == other.step &&
          waitingOnYou == other.waitingOnYou &&
          autoApprove == other.autoApprove &&
          costUsd == other.costUsd &&
          taskId == other.taskId &&
          lastSeen == other.lastSeen;

  @override
  int get hashCode => Object.hash(
    nodeId,
    sessionId,
    kind,
    project,
    title,
    status,
    step,
    waitingOnYou,
    autoApprove,
    costUsd,
    taskId,
    lastSeen,
  );
}

/// Everything the nodes that reported in the last 30 s report.
@immutable
class LiveSessionsState {
  const LiveSessionsState({
    this.sessions = const <LiveSession>[],
    this.loading = false,
    this.failure,
  });

  final List<LiveSession> sessions;
  final bool loading;

  /// The last read that failed; the sessions on screen stay.
  final KeelApiFailure? failure;

  /// The groups that have something, in [LiveSessionGroup] order.
  List<(LiveSessionGroup, List<LiveSession>)> get groups => [
    for (final group in LiveSessionGroup.values)
      if (sessions.where((session) => session.group == group).toList()
          case final List<LiveSession> members when members.isNotEmpty)
        (group, members),
  ];

  LiveSessionsState copyWith({
    List<LiveSession>? sessions,
    bool? loading,
    KeelApiFailure? failure,
    bool clearFailure = false,
  }) => LiveSessionsState(
    sessions: sessions ?? this.sessions,
    loading: loading ?? this.loading,
    failure: clearFailure ? null : (failure ?? this.failure),
  );

  factory LiveSessionsState.fromJson(Map<String, dynamic> json) =>
      LiveSessionsState(
        sessions: <LiveSession>[
          for (final row in json['sessions'] as List<Object?>? ?? const [])
            if (row is Map<String, dynamic>) LiveSession.fromJson(row),
        ],
        loading: KeelJson.decodeBool(json['loading']),
        failure: switch (json['failure']) {
          final Map<String, dynamic> failure => KeelApiFailure.fromJson(
            failure,
          ),
          _ => null,
        },
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sessions': sessions.map((session) => session.toJson()).toList(),
    'loading': loading,
    'failure': failure?.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiveSessionsState &&
          listEquals(sessions, other.sessions) &&
          loading == other.loading &&
          failure == other.failure;

  @override
  int get hashCode => Object.hash(Object.hashAll(sessions), loading, failure);
}
