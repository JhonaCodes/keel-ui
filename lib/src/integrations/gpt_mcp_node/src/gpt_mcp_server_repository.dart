part of '../gpt_mcp_node.dart';

/// The server's GPT MCP through keel-api's task queue: a `gpt.*` task
/// addressed to the server node, which answers it in `result_json`
/// (keel-core's `GptMcpTasks`). keel-ui waits for the answer by polling the
/// task, as the server chat does with Keel AI.
class GptMcpServerRepository {
  const GptMcpServerRepository();

  static const _pollEvery = Duration(milliseconds: 1500);

  /// A task still waiting for a node after this is dropped: the server is
  /// offline or not taking work.
  static const _takeWithin = Duration(seconds: 30);
  static const _answerWithin = Duration(seconds: 60);

  RemoteTasksRepository get _tasks => const RemoteTasksRepository();
  KeelNodesRepository get _nodes => const KeelNodesRepository();
  KeelApiClient get _client => KeelApiService.client.notifier;

  /// The first online server node, or why there is none.
  Future<Result<String, String>> serverNodeId() async {
    final listed = await _nodes.list();
    return listed.when(
      ok: (nodes) {
        final server = nodes.where((n) => n.isServer && n.online).firstOrNull;
        return server == null
            ? Err('No server node is online in your Keel account.')
            : Ok(server.id);
      },
      err: (failure) =>
          Err(failure.serverMessage ?? 'keel-api is not reachable.'),
    );
  }

  /// Runs one `gpt.*` task on [nodeId] and returns its result.
  Future<Result<Map<String, dynamic>, String>> run(
    String nodeId,
    String type,
    Map<String, Object?> payload,
  ) async {
    final created = await _tasks.create(
      RemoteTaskDraft(
        type: type,
        nodeId: nodeId,
        payloadJson: KeelJson.encode(payload),
      ),
    );
    if (created.isErr) {
      return Err(
        created.errorOrNull!.serverMessage ?? 'keel-api refused the task.',
      );
    }
    final id = created.data.id;
    final started = DateTime.now();
    while (true) {
      await Future<void>.delayed(_pollEvery);
      final read = await _client.getObject(KeelApiPaths.task(id));
      if (read.isErr) continue;
      final row = read.data;
      final task = RemoteTask.fromJson(row);
      final waited = DateTime.now().difference(started);
      if (task.isTerminal) {
        final result = KeelJson.decodeObject(row['result_json'] as String?);
        return task.status == RemoteTaskStatus.done
            ? Ok(Map<String, dynamic>.from(result))
            : Err(
                result['error'] as String? ?? 'The server did not run $type.',
              );
      }
      if (task.status == RemoteTaskStatus.todo && waited > _takeWithin) {
        await _tasks.cancel(id);
        return Err('The server did not take the request: is it online?');
      }
      if (waited > _answerWithin) {
        await _tasks.cancel(id);
        return Err('The server took too long to answer.');
      }
    }
  }
}
