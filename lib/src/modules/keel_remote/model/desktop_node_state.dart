import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/integrations/keel_api/keel_api.dart';

/// Where this PC stands as a keel-api node.
enum DesktopNodeStatus {
  /// Not a node.
  off,

  /// Enrolling, or starting the node kept from before.
  connecting,

  /// Taking the app's tasks.
  on,

  /// Enrolled, but the node could not start on this PC: only disconnecting
  /// is offered.
  failed,

  /// Stopping and unlinking.
  disconnecting;

  static DesktopNodeStatus fromName(String? name) => values.firstWhere(
    (status) => status.name == name,
    orElse: () => DesktopNodeStatus.off,
  );
}

/// What went wrong on this PC's side; what the server answered is a
/// [KeelApiFailure].
enum DesktopNodeProblem {
  /// The node's token could not be kept owner-only, so it was not kept and
  /// the node was unlinked again.
  tokenNotStored,

  /// The node is enrolled but could not start here.
  notStarted,

  /// This PC stopped taking tasks, but the server did not confirm it
  /// unlinked the node.
  unlinkNotConfirmed;

  static DesktopNodeProblem? fromName(String? name) =>
      values.where((problem) => problem.name == name).firstOrNull;
}

/// How the last call to one keel-api endpoint went.
@immutable
class DesktopNodeCall {
  const DesktopNodeCall({
    required this.at,
    required this.ok,
    required this.outcome,
  });

  final DateTime at;
  final bool ok;

  /// `HTTP 200`, or why there was no answer.
  final String outcome;

  factory DesktopNodeCall.fromJson(Map<String, dynamic> json) =>
      DesktopNodeCall(
        at: KeelJson.decodeTimestamp(json['at']) ?? DateTime.now(),
        ok: KeelJson.decodeBool(json['ok']),
        outcome: json['outcome'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'at': at.toUtc().toIso8601String(),
    'ok': ok,
    'outcome': outcome,
  };

  DesktopNodeCall copyWith({DateTime? at, bool? ok, String? outcome}) =>
      DesktopNodeCall(
        at: at ?? this.at,
        ok: ok ?? this.ok,
        outcome: outcome ?? this.outcome,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DesktopNodeCall &&
          at == other.at &&
          ok == other.ok &&
          outcome == other.outcome;

  @override
  int get hashCode => Object.hash(at, ok, outcome);
}

/// One line of the node link's log, as the panel shows it.
@immutable
class DesktopNodeLogLine {
  const DesktopNodeLogLine({
    required this.at,
    required this.level,
    required this.title,
    this.count = 1,
  });

  final DateTime at;

  /// `ok`, `info`, `warn` or `error`.
  final String level;
  final String title;

  /// How many times it happened in a row.
  final int count;

  bool get isError => level == 'error';

  factory DesktopNodeLogLine.fromJson(Map<String, dynamic> json) =>
      DesktopNodeLogLine(
        at: KeelJson.decodeTimestamp(json['at']) ?? DateTime.now(),
        level: json['level'] as String? ?? 'info',
        title: json['title'] as String? ?? '',
        count: KeelJson.decodeInt(json['count']) ?? 1,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'at': at.toUtc().toIso8601String(),
    'level': level,
    'title': title,
    'count': count,
  };

  DesktopNodeLogLine copyWith({
    DateTime? at,
    String? level,
    String? title,
    int? count,
  }) => DesktopNodeLogLine(
    at: at ?? this.at,
    level: level ?? this.level,
    title: title ?? this.title,
    count: count ?? this.count,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DesktopNodeLogLine &&
          at == other.at &&
          level == other.level &&
          title == other.title &&
          count == other.count;

  @override
  int get hashCode => Object.hash(at, level, title, count);
}

/// A session of this PC with «Aceptar todo» on: the node answers every
/// permission it asks for.
@immutable
class DesktopNodeAutoApproval {
  const DesktopNodeAutoApproval({
    required this.sessionId,
    required this.project,
    required this.title,
  });

  final String sessionId;
  final String project;
  final String title;

  factory DesktopNodeAutoApproval.fromJson(Map<String, dynamic> json) =>
      DesktopNodeAutoApproval(
        sessionId: json['session_id'] as String? ?? '',
        project: json['project'] as String? ?? '',
        title: json['title'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'session_id': sessionId,
    'project': project,
    'title': title,
  };

  DesktopNodeAutoApproval copyWith({
    String? sessionId,
    String? project,
    String? title,
  }) => DesktopNodeAutoApproval(
    sessionId: sessionId ?? this.sessionId,
    project: project ?? this.project,
    title: title ?? this.title,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DesktopNodeAutoApproval &&
          sessionId == other.sessionId &&
          project == other.project &&
          title == other.title;

  @override
  int get hashCode => Object.hash(sessionId, project, title);
}

/// This PC as a node: whether it is one, which, and how its link is doing.
@immutable
class DesktopNodeState {
  const DesktopNodeState({
    this.status = DesktopNodeStatus.off,
    this.nodeId = '',
    this.failure,
    this.problem,
    this.lastPoll,
    this.lastReport,
    this.tasksTaken = 0,
    this.recent = const <DesktopNodeLogLine>[],
    this.keelAi = false,
    this.autoApproved = const <DesktopNodeAutoApproval>[],
  });

  final DesktopNodeStatus status;

  /// The id keel-api knows this PC by; empty while it is not a node.
  final String nodeId;

  /// What the server answered when connecting or disconnecting failed.
  final KeelApiFailure? failure;
  final DesktopNodeProblem? problem;

  /// The last call to the task queue (`tasks`): the poll, most of the time.
  final DesktopNodeCall? lastPoll;

  /// The last status report (`nodes/{id}/status`), which also keeps the node
  /// online for the app.
  final DesktopNodeCall? lastReport;

  /// The tasks this node took since it started.
  final int tasksTaken;

  /// The link's last lines, oldest first.
  final List<DesktopNodeLogLine> recent;

  /// Whether Keel AI runs on this node: the Keel app chats with it.
  final bool keelAi;

  /// The sessions still going with «Aceptar todo» on.
  final List<DesktopNodeAutoApproval> autoApproved;

  bool get isOn => status == DesktopNodeStatus.on;
  bool get isBusy =>
      status == DesktopNodeStatus.connecting ||
      status == DesktopNodeStatus.disconnecting;
  bool get canConnect => status == DesktopNodeStatus.off;
  bool get canDisconnect =>
      status == DesktopNodeStatus.on || status == DesktopNodeStatus.failed;

  DesktopNodeState copyWith({
    DesktopNodeStatus? status,
    String? nodeId,
    KeelApiFailure? failure,
    bool clearFailure = false,
    DesktopNodeProblem? problem,
    bool clearProblem = false,
    DesktopNodeCall? lastPoll,
    DesktopNodeCall? lastReport,
    int? tasksTaken,
    List<DesktopNodeLogLine>? recent,
    bool? keelAi,
    List<DesktopNodeAutoApproval>? autoApproved,
  }) => DesktopNodeState(
    status: status ?? this.status,
    nodeId: nodeId ?? this.nodeId,
    failure: clearFailure ? null : (failure ?? this.failure),
    problem: clearProblem ? null : (problem ?? this.problem),
    lastPoll: lastPoll ?? this.lastPoll,
    lastReport: lastReport ?? this.lastReport,
    tasksTaken: tasksTaken ?? this.tasksTaken,
    recent: recent ?? this.recent,
    keelAi: keelAi ?? this.keelAi,
    autoApproved: autoApproved ?? this.autoApproved,
  );

  factory DesktopNodeState.fromJson(Map<String, dynamic> json) =>
      DesktopNodeState(
        status: DesktopNodeStatus.fromName(json['status'] as String?),
        nodeId: json['node_id'] as String? ?? '',
        failure: switch (json['failure']) {
          final Map<String, dynamic> failure => KeelApiFailure.fromJson(
            failure,
          ),
          _ => null,
        },
        problem: DesktopNodeProblem.fromName(json['problem'] as String?),
        lastPoll: switch (json['last_poll']) {
          final Map<String, dynamic> call => DesktopNodeCall.fromJson(call),
          _ => null,
        },
        lastReport: switch (json['last_report']) {
          final Map<String, dynamic> call => DesktopNodeCall.fromJson(call),
          _ => null,
        },
        tasksTaken: KeelJson.decodeInt(json['tasks_taken']) ?? 0,
        recent: <DesktopNodeLogLine>[
          for (final line in json['recent'] as List<Object?>? ?? const [])
            if (line is Map<String, dynamic>) DesktopNodeLogLine.fromJson(line),
        ],
        keelAi: KeelJson.decodeBool(json['keel_ai']),
        autoApproved: <DesktopNodeAutoApproval>[
          for (final item in json['auto_approved'] as List<Object?>? ?? [])
            if (item is Map<String, dynamic>)
              DesktopNodeAutoApproval.fromJson(item),
        ],
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'status': status.name,
    'node_id': nodeId,
    'failure': failure?.toJson(),
    'problem': problem?.name,
    'last_poll': lastPoll?.toJson(),
    'last_report': lastReport?.toJson(),
    'tasks_taken': tasksTaken,
    'recent': recent.map((line) => line.toJson()).toList(),
    'keel_ai': keelAi,
    'auto_approved': autoApproved.map((session) => session.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DesktopNodeState &&
          status == other.status &&
          nodeId == other.nodeId &&
          failure == other.failure &&
          problem == other.problem &&
          lastPoll == other.lastPoll &&
          lastReport == other.lastReport &&
          tasksTaken == other.tasksTaken &&
          listEquals(recent, other.recent) &&
          keelAi == other.keelAi &&
          listEquals(autoApproved, other.autoApproved);

  @override
  int get hashCode => Object.hash(
    status,
    nodeId,
    failure,
    problem,
    lastPoll,
    lastReport,
    tasksTaken,
    Object.hashAll(recent),
    keelAi,
    Object.hashAll(autoApproved),
  );
}
