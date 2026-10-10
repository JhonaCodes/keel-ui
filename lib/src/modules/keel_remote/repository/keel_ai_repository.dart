/// Keel AI on a server node, through `keelai.*` tasks addressed to it.
///
/// keel-api only queues them; the node takes each on its next pass and ends
/// it with its answer in `result_json`: `keelai.new` → `{conversation_id}`,
/// `keelai.send` → `{conversation_id, reply}`, or a cancelled task with
/// `{error}`. While it answers, the node reports what it is doing as the
/// `step` of its `chat-<conversation_id>` item in `/workers/sessions`.
library;

import 'package:result_controller/result_controller.dart';

import 'package:keel_ui/src/integrations/keel_api/keel_api.dart';
import 'package:keel_ui/src/modules/keel_remote/model/live_session.dart';
import 'package:keel_ui/src/modules/keel_remote/model/remote_task.dart';
import 'package:keel_ui/src/modules/keel_remote/repository/live_sessions_repository.dart';
import 'package:keel_ui/src/modules/keel_remote/repository/remote_tasks_repository.dart';

class KeelAiRepository {
  const KeelAiRepository();

  RemoteTasksRepository get _tasks => const RemoteTasksRepository();
  LiveSessionsRepository get _sessions => const LiveSessionsRepository();

  /// A new conversation on [nodeId].
  Future<Result<RemoteTask, KeelApiFailure>> open({required String nodeId}) =>
      _tasks.create(RemoteTaskDraft(type: 'keelai.new', nodeId: nodeId));

  Future<Result<RemoteTask, KeelApiFailure>> send({
    required String nodeId,
    required String conversationId,
    required String text,
  }) => _tasks.create(
    RemoteTaskDraft(
      type: 'keelai.send',
      nodeId: nodeId,
      payloadJson: KeelJson.encode(<String, dynamic>{
        'text': text,
        'conversation_id': conversationId,
      }),
    ),
  );

  Future<Result<RemoteTask, KeelApiFailure>> byId(String taskId) =>
      _tasks.byId(taskId);

  Future<Result<RemoteTask, KeelApiFailure>> cancel(String taskId) =>
      _tasks.cancel(taskId);

  /// What Keel AI on [nodeId] reports doing in [conversationId]; null while
  /// the node reports nothing for it.
  Future<Result<String?, KeelApiFailure>> liveStep({
    required String nodeId,
    required String conversationId,
  }) async => (await _sessions.list()).map(
    (sessions) => sessions
        .where(
          (session) =>
              session.nodeId == nodeId &&
              session.kind == LiveSessionKind.keelAi &&
              LiveSessionKind.keelAi.idIn(session.sessionId) == conversationId,
        )
        .firstOrNull
        ?.step,
  );
}
