/// `/v1/keel-bot/tasks`: the queue, one task, its history, creating and
/// cancelling.
library;

import 'package:result_controller/result_controller.dart';

import 'package:keel_ui/src/integrations/keel_api/keel_api.dart';
import 'package:keel_ui/src/modules/keel_remote/model/remote_task.dart';

class RemoteTasksRepository {
  const RemoteTasksRepository();

  /// keel-api's page size.
  static const int pageSize = 50;

  KeelApiClient get _client => KeelApiService.client.notifier;

  /// Newest first. [status] null lists every status.
  Future<Result<List<RemoteTask>, KeelApiFailure>> list({
    RemoteTaskStatus? status,
  }) async => (await _client.getList(
    KeelApiPaths.tasks,
    query: <String, Object?>{'status': status?.wireValue, 'limit': pageSize},
  )).map((rows) => rows.map(RemoteTask.fromJson).toList(growable: false));

  Future<Result<RemoteTask, KeelApiFailure>> byId(String id) async =>
      (await _client.getObject(KeelApiPaths.task(id))).map(RemoteTask.fromJson);

  /// The append-only history, oldest first.
  Future<Result<List<RemoteTaskEvent>, KeelApiFailure>> events(
    String id,
  ) async => (await _client.getList(
    KeelApiPaths.taskEvents(id),
  )).map((rows) => rows.map(RemoteTaskEvent.fromJson).toList(growable: false));

  Future<Result<RemoteTask, KeelApiFailure>> create(
    RemoteTaskDraft draft,
  ) async => (await _client.postObject(
    KeelApiPaths.tasks,
    body: draft.toJson(),
  )).map(RemoteTask.fromJson);

  /// Cancels a task that is not terminal. It stays in the history as
  /// `cancelled`; a cancelled `keelai.send` stops Keel AI's turn too.
  Future<Result<RemoteTask, KeelApiFailure>> cancel(String id) async =>
      (await _client.deleteObject(
        KeelApiPaths.task(id),
      )).map(RemoteTask.fromJson);
}
