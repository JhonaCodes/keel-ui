import 'dart:async';

import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:result_controller/result_controller.dart';

import 'package:keel_ui/src/integrations/keel_api/keel_api.dart';
import 'package:keel_ui/src/modules/keel_remote/model/remote_task.dart';
import 'package:keel_ui/src/modules/keel_remote/model/server_chat.dart';
import 'package:keel_ui/src/modules/keel_remote/repository/keel_ai_repository.dart';
import 'package:keel_ui/src/modules/keel_remote/viewmodel/keel_nodes_viewmodel.dart';

/// A conversation with Keel AI on a keel-server node — the server's own
/// assistant, not the one in this machine's Keel AI window.
///
/// Each message is a `keelai.send` task addressed to the node; the first one
/// opens the conversation there with `keelai.new`. The answer is waited for
/// the way keel-bot waits for it: the task is read every [pollEvery] until
/// it ends, and meanwhile the step the node reports for the conversation is
/// shown. A task no node takes in [stallAfter] is cancelled.
class ServerChatViewModel extends ViewModel<ServerChatState> {
  ServerChatViewModel() : super(const ServerChatState());

  static const Duration pollEvery = Duration(seconds: 2);
  static const Duration stallAfter = Duration(seconds: 60);

  KeelAiRepository get _keelAi => const KeelAiRepository();

  /// Bumped by every turn and every stop: a turn whose epoch moved on stops
  /// reading and lands nothing.
  int _epoch = 0;
  int _sequence = 0;

  @override
  void init() {}

  /// The node the next message goes to: the one chosen while it is an
  /// online server, else the first online server; null when none is.
  String? get targetNodeId {
    final servers = KeelNodesService.instance.notifier.data.onlineServers;
    final chosen = data.nodeId;
    if (servers.any((node) => node.id == chosen)) return chosen;
    return servers.firstOrNull?.id;
  }

  /// Talks to Keel AI on [nodeId] from now on. Another node is another
  /// conversation.
  void selectNode(String? nodeId) {
    if (nodeId == null || nodeId == data.nodeId) return;
    _stop();
    updateState(ServerChatState(nodeId: nodeId));
  }

  /// Starts over on the same node.
  void newConversation() {
    _stop();
    updateState(ServerChatState(nodeId: data.nodeId));
  }

  /// Sends [text] and waits for Keel AI's answer.
  Future<void> send(String text) async {
    final message = text.trim();
    if (message.isEmpty || data.waiting) return;
    final epoch = ++_epoch;
    final nodeId = targetNodeId;
    if (nodeId != data.nodeId) {
      // A conversation only exists on the node that opened it.
      updateState(ServerChatState(nodeId: nodeId, messages: data.messages));
    }
    transformState(
      (state) => state.copyWith(
        messages: [...state.messages, _message(ServerChatRole.person, message)],
        waiting: true,
        clearStep: true,
      ),
    );
    if (nodeId == null) {
      _fail(const KeelApiFailure(kind: KeelApiFailureKind.noOnlineNode));
      return;
    }

    var conversationId = data.conversationId;
    if (conversationId == null) {
      final opened = await _open(nodeId, epoch);
      if (epoch != _epoch || isDisposed) return;
      switch (opened) {
        case Err(:final error):
          _fail(error);
          return;
        case Ok(data: final opened):
          conversationId = opened;
          transformState((state) => state.copyWith(conversationId: opened));
      }
    }
    if (conversationId == null) return;

    final sent = await _keelAi.send(
      nodeId: nodeId,
      conversationId: conversationId,
      text: message,
    );
    if (epoch != _epoch || isDisposed) {
      if (sent case Ok(data: final task)) unawaited(_keelAi.cancel(task.id));
      return;
    }
    if (sent case Err(:final error)) {
      _fail(error);
      return;
    }
    final taskId = sent.data.id;
    transformState((state) => state.copyWith(taskId: taskId));

    final ended = await _awaitTask(
      taskId,
      epoch,
      nodeId: nodeId,
      conversationId: conversationId,
    );
    if (epoch != _epoch || isDisposed) return;
    switch (ended) {
      case Err(:final error):
        _fail(error);
      case Ok(data: final task) when task.status == RemoteTaskStatus.done:
        transformState(
          (state) => state.copyWith(
            messages: [
              ...state.messages,
              _message(ServerChatRole.keelAi, task.result?.reply?.trim() ?? ''),
            ],
            waiting: false,
            clearStep: true,
            clearTaskId: true,
          ),
        );
      case Ok(data: final task):
        _fail(_nodeFailure(task));
    }
  }

  /// Stops waiting and cancels the turn's task: on the node, a cancelled
  /// `keelai.send` stops Keel AI's turn too.
  void cancel() {
    _stop();
    if (data.waiting) {
      transformState(
        (state) =>
            state.copyWith(waiting: false, clearStep: true, clearTaskId: true),
      );
    }
  }

  /// Forgets what the previous session showed.
  void clear() {
    _epoch++;
    updateState(const ServerChatState());
  }

  void _stop() {
    _epoch++;
    final taskId = data.taskId;
    if (taskId != null) unawaited(_keelAi.cancel(taskId));
  }

  /// Opens a conversation on [nodeId] (`keelai.new` ends on the node's next
  /// pass) and answers its id.
  Future<Result<String, KeelApiFailure>> _open(String nodeId, int epoch) async {
    final created = await _keelAi.open(nodeId: nodeId);
    if (created case Err(:final error)) return Err(error);
    final ended = await _awaitTask(created.data.id, epoch);
    return ended.flatMap(
      (task) => switch ((task.status, task.result?.conversationId)) {
        (RemoteTaskStatus.done, final String id) => Ok(id),
        _ => Err(_nodeFailure(task)),
      },
    );
  }

  /// Reads [taskId] until it ends, or until it is clear no node takes it.
  /// With a [conversationId], the step the node reports is shown meanwhile.
  Future<Result<RemoteTask, KeelApiFailure>> _awaitTask(
    String taskId,
    int epoch, {
    String? nodeId,
    String? conversationId,
  }) async {
    final sentAt = DateTime.now();
    while (true) {
      await Future<void>.delayed(pollEvery);
      if (epoch != _epoch || isDisposed) return Err(_superseded);
      final read = await _keelAi.byId(taskId);
      if (epoch != _epoch || isDisposed) return Err(_superseded);
      switch (read) {
        case Err(:final error) when !error.isTransient:
          return Err(error);
        case Ok(data: final task) when task.isTerminal:
          return Ok(task);
        case Ok(data: final task)
            when task.status == RemoteTaskStatus.todo &&
                DateTime.now().difference(sentAt) > stallAfter:
          unawaited(_keelAi.cancel(taskId));
          return Err(const KeelApiFailure(kind: KeelApiFailureKind.stalled));
        default:
          break;
      }
      if (nodeId == null || conversationId == null) continue;
      final live = await _keelAi.liveStep(
        nodeId: nodeId,
        conversationId: conversationId,
      );
      if (epoch != _epoch || isDisposed) return Err(_superseded);
      final step = live.when(ok: (step) => step?.trim(), err: (_) => null);
      if (step != null && step.isNotEmpty && step != data.step) {
        transformState((state) => state.copyWith(step: step));
      }
    }
  }

  void _fail(KeelApiFailure failure) => transformState(
    (state) => state.copyWith(
      messages: [
        ...state.messages,
        _message(ServerChatRole.notice, '', failure: failure),
      ],
      waiting: false,
      clearStep: true,
      clearTaskId: true,
    ),
  );

  ServerChatMessage _message(
    ServerChatRole role,
    String text, {
    KeelApiFailure? failure,
  }) => ServerChatMessage(
    id: 'server-chat-${++_sequence}',
    role: role,
    text: text,
    at: DateTime.now(),
    failure: failure,
  );

  static KeelApiFailure _nodeFailure(RemoteTask task) => KeelApiFailure(
    kind: KeelApiFailureKind.nodeFailed,
    serverMessage: task.result?.error,
  );

  /// What a superseded wait answers; its caller never shows it.
  static const KeelApiFailure _superseded = KeelApiFailure(
    kind: KeelApiFailureKind.unexpected,
  );
}

mixin ServerChatService {
  static final ReactiveNotifier<ServerChatViewModel> instance =
      ReactiveNotifier<ServerChatViewModel>(ServerChatViewModel.new);
}
