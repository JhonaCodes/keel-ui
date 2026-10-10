/// A task in keel-api's queue (`/v1/keel-bot/tasks`): work the person (or a
/// hook, a job, a node) asked a node to do, and what the node reported back.
library;

import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/integrations/keel_api/keel_api.dart';

/// The six statuses of a task. `done` and `cancelled` are terminal.
enum RemoteTaskStatus {
  todo('todo'),
  evaluating('evaluating'),
  inProgress('in_progress'),
  paused('paused'),
  done('done'),
  cancelled('cancelled');

  const RemoteTaskStatus(this.wireValue);

  final String wireValue;

  /// Old rows (`pending`, `acked`, `failed`) read as keel-api reads them.
  static RemoteTaskStatus fromWire(String? value) => switch (value) {
    'acked' => evaluating,
    'failed' => cancelled,
    _ => values.firstWhere(
      (status) => status.wireValue == value,
      orElse: () => todo,
    ),
  };
}

/// What a node put in `result_json`: progress while it works, the outcome
/// when it ends. keel-api validates none of it, so every field is optional.
///
/// The `keelai.*` tasks answer here too: `conversation_id` and `reply`.
@immutable
class RemoteTaskResult {
  const RemoteTaskResult({
    this.step,
    this.confidence,
    this.summary,
    this.error,
    this.prUrl,
    this.sessionId,
    this.conversationId,
    this.reply,
  });

  /// The step the node is on.
  final String? step;

  /// 0–100: how far along, or how sure the node is at the end.
  final int? confidence;

  /// The node's closing report, in Markdown.
  final String? summary;

  /// Why it failed, on a task the node cancelled.
  final String? error;
  final String? prUrl;

  /// The session the task runs, on its node.
  final String? sessionId;

  /// The Keel AI conversation a `keelai.new` opened or a `keelai.send` used.
  final String? conversationId;

  /// Keel AI's answer to a `keelai.send`.
  final String? reply;

  bool get hasError => error?.trim().isNotEmpty ?? false;

  factory RemoteTaskResult.fromJson(Map<String, dynamic> json) =>
      RemoteTaskResult(
        step: KeelJson.decodeText(json['step']),
        confidence: KeelJson.decodeInt(json['confidence']),
        summary: KeelJson.decodeText(json['summary']),
        error: KeelJson.decodeText(json['error']),
        prUrl: KeelJson.decodeText(json['pr_url']),
        sessionId: KeelJson.decodeText(json['session_id']),
        conversationId: KeelJson.decodeText(json['conversation_id']),
        reply: json['reply'] as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'step': ?step,
    'confidence': ?confidence,
    'summary': ?summary,
    'error': ?error,
    'pr_url': ?prUrl,
    'session_id': ?sessionId,
    'conversation_id': ?conversationId,
    'reply': ?reply,
  };

  RemoteTaskResult copyWith({
    String? step,
    int? confidence,
    String? summary,
    String? error,
    String? prUrl,
    String? sessionId,
    String? conversationId,
    String? reply,
  }) => RemoteTaskResult(
    step: step ?? this.step,
    confidence: confidence ?? this.confidence,
    summary: summary ?? this.summary,
    error: error ?? this.error,
    prUrl: prUrl ?? this.prUrl,
    sessionId: sessionId ?? this.sessionId,
    conversationId: conversationId ?? this.conversationId,
    reply: reply ?? this.reply,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteTaskResult &&
          step == other.step &&
          confidence == other.confidence &&
          summary == other.summary &&
          error == other.error &&
          prUrl == other.prUrl &&
          sessionId == other.sessionId &&
          conversationId == other.conversationId &&
          reply == other.reply;

  @override
  int get hashCode => Object.hash(
    step,
    confidence,
    summary,
    error,
    prUrl,
    sessionId,
    conversationId,
    reply,
  );
}

@immutable
class RemoteTask {
  const RemoteTask({
    required this.id,
    required this.type,
    required this.source,
    required this.status,
    required this.isTerminal,
    required this.payloadJson,
    this.project,
    this.nodeId,
    this.workerId,
    this.result,
    this.createdAt,
    this.ackedAt,
    this.completedAt,
  });

  final String id;

  /// What kind of work: `scan_tickets`, `deploy.run`, `keelai.send`…
  final String type;

  /// Who created it: `app`, `node`, `hook:<name>`, `webhook:github`…
  final String source;
  final RemoteTaskStatus status;

  /// keel-api's own flag, trusted over [status]: an imported row can carry
  /// a status name this app does not know.
  final bool isTerminal;

  /// The input of the work, as JSON text.
  final String payloadJson;
  final String? project;

  /// The node it is addressed to; null when any node may take it.
  final String? nodeId;

  /// The node that took it.
  final String? workerId;
  final RemoteTaskResult? result;
  final DateTime? createdAt;
  final DateTime? ackedAt;
  final DateTime? completedAt;

  /// The node it runs on, or the one it waits for.
  String? get placedOn => workerId ?? nodeId;

  bool get canCancel => !isTerminal;

  factory RemoteTask.fromJson(Map<String, dynamic> json) {
    final result = KeelJson.decodeObject(json['result_json'] as String?);
    return RemoteTask(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      source: json['source'] as String? ?? '',
      status: RemoteTaskStatus.fromWire(json['status'] as String?),
      isTerminal: KeelJson.decodeBool(json['is_terminal']),
      payloadJson: json['payload_json'] as String? ?? '',
      project: KeelJson.decodeText(json['project']),
      nodeId: KeelJson.decodeText(json['node_id']),
      workerId: KeelJson.decodeText(json['worker_id']),
      result: result.isEmpty ? null : RemoteTaskResult.fromJson(result),
      createdAt: KeelJson.decodeTimestamp(json['created_at']),
      ackedAt: KeelJson.decodeTimestamp(json['acked_at']),
      completedAt: KeelJson.decodeTimestamp(json['completed_at']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type,
    'source': source,
    'status': status.wireValue,
    'is_terminal': isTerminal,
    'payload_json': payloadJson,
    'project': project,
    'node_id': nodeId,
    'worker_id': workerId,
    'result_json': switch (result) {
      final RemoteTaskResult value => KeelJson.encode(value.toJson()),
      null => null,
    },
    'created_at': createdAt?.toUtc().toIso8601String(),
    'acked_at': ackedAt?.toUtc().toIso8601String(),
    'completed_at': completedAt?.toUtc().toIso8601String(),
  };

  RemoteTask copyWith({
    String? id,
    String? type,
    String? source,
    RemoteTaskStatus? status,
    bool? isTerminal,
    String? payloadJson,
    String? project,
    String? nodeId,
    String? workerId,
    RemoteTaskResult? result,
    DateTime? createdAt,
    DateTime? ackedAt,
    DateTime? completedAt,
  }) => RemoteTask(
    id: id ?? this.id,
    type: type ?? this.type,
    source: source ?? this.source,
    status: status ?? this.status,
    isTerminal: isTerminal ?? this.isTerminal,
    payloadJson: payloadJson ?? this.payloadJson,
    project: project ?? this.project,
    nodeId: nodeId ?? this.nodeId,
    workerId: workerId ?? this.workerId,
    result: result ?? this.result,
    createdAt: createdAt ?? this.createdAt,
    ackedAt: ackedAt ?? this.ackedAt,
    completedAt: completedAt ?? this.completedAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteTask &&
          id == other.id &&
          type == other.type &&
          source == other.source &&
          status == other.status &&
          isTerminal == other.isTerminal &&
          payloadJson == other.payloadJson &&
          project == other.project &&
          nodeId == other.nodeId &&
          workerId == other.workerId &&
          result == other.result &&
          createdAt == other.createdAt &&
          ackedAt == other.ackedAt &&
          completedAt == other.completedAt;

  @override
  int get hashCode => Object.hash(
    id,
    type,
    source,
    status,
    isTerminal,
    payloadJson,
    project,
    nodeId,
    workerId,
    result,
    createdAt,
    ackedAt,
    completedAt,
  );
}

/// One entry of a task's append-only history (`GET /tasks/{id}/events`):
/// a message, a step, an approval asked or answered, an action applied.
@immutable
class RemoteTaskEvent {
  const RemoteTaskEvent({
    required this.id,
    required this.kind,
    required this.payload,
    this.createdAt,
  });

  final int id;

  /// `message`, `step`, `decision.opened`, `decision.answered`,
  /// `action.applied` or `action.failed`.
  final String kind;
  final Map<String, Object?> payload;
  final DateTime? createdAt;

  /// Who wrote a `message`: `user` for the person, else the agent. Keel AI
  /// snapshots name it `role`.
  String? get author => _field('author') ?? _field('role');

  /// The text of a `message`.
  String? get text => _field('text');

  /// What a `step` is: its title (sessions) or its key (launches).
  String? get stepTitle => _field('title') ?? _field('step');

  /// Where a `step` stands: `running`, `done`, `failed`…
  String? get stepState => _field('status') ?? _field('state');

  /// More about a `step` or an applied action.
  String? get detail => _field('detail') ?? _field('cloudflare');

  /// What a `decision.*` asks.
  String? get question => _field('question');

  /// The answers a `decision.opened` accepts.
  List<String> get options => <String>[
    for (final option in payload['options'] as List<Object?>? ?? const [])
      if (option is String) option,
  ];

  /// What a `decision.answered` was answered with.
  String? get answer => _field('answer');

  /// Why an `action.failed` failed.
  String? get error => _field('error');

  /// The payload as JSON text, for a kind this app does not know.
  String get rawPayload => KeelJson.encode(payload);

  String? _field(String name) => KeelJson.decodeText(payload[name])?.trim();

  factory RemoteTaskEvent.fromJson(Map<String, dynamic> json) =>
      RemoteTaskEvent(
        id: KeelJson.decodeInt(json['id']) ?? 0,
        kind: json['kind'] as String? ?? '',
        payload: KeelJson.decodeObject(json['payload_json'] as String?),
        createdAt: KeelJson.decodeTimestamp(json['created_at']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'kind': kind,
    'payload_json': KeelJson.encode(payload),
    'created_at': createdAt?.toUtc().toIso8601String(),
  };

  RemoteTaskEvent copyWith({
    int? id,
    String? kind,
    Map<String, Object?>? payload,
    DateTime? createdAt,
  }) => RemoteTaskEvent(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteTaskEvent &&
          id == other.id &&
          kind == other.kind &&
          mapEquals(payload, other.payload) &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    Object.hashAllUnordered(
      payload.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
    createdAt,
  );
}

/// What the «Nueva tarea» form sends: `POST /tasks` with a type, an
/// optional project, a JSON payload and the online node it is for.
@immutable
class RemoteTaskDraft {
  const RemoteTaskDraft({
    required this.type,
    required this.nodeId,
    this.project = '',
    this.payloadJson = '{}',
  });

  final String type;
  final String? nodeId;
  final String project;
  final String payloadJson;

  factory RemoteTaskDraft.fromJson(Map<String, dynamic> json) =>
      RemoteTaskDraft(
        type: json['type'] as String? ?? '',
        nodeId: json['node_id'] as String?,
        project: json['project'] as String? ?? '',
        payloadJson: json['payload_json'] as String? ?? '{}',
      );

  /// The wire body. The node id travels at the top and inside the payload,
  /// which is where keel-server reads it.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type.trim(),
    'source': 'app',
    'payload_json': KeelJson.encode(<String, dynamic>{
      ...KeelJson.decodeObject(payloadJson),
      'node_id': ?nodeId,
    }),
    if (project.trim().isNotEmpty) 'project': project.trim(),
    'node_id': ?nodeId,
  };

  RemoteTaskDraft copyWith({
    String? type,
    String? nodeId,
    String? project,
    String? payloadJson,
  }) => RemoteTaskDraft(
    type: type ?? this.type,
    nodeId: nodeId ?? this.nodeId,
    project: project ?? this.project,
    payloadJson: payloadJson ?? this.payloadJson,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteTaskDraft &&
          type == other.type &&
          nodeId == other.nodeId &&
          project == other.project &&
          payloadJson == other.payloadJson;

  @override
  int get hashCode => Object.hash(type, nodeId, project, payloadJson);
}

/// Why a [RemoteTaskDraft] cannot be sent yet.
enum RemoteTaskDraftProblem { missingType, payloadNotObject, nodeNotOnline }
