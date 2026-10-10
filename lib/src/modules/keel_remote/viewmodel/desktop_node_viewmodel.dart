import 'dart:async';
import 'dart:io';

import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:result_controller/result_controller.dart';

import 'package:keel_ui/src/integrations/keel_api/keel_api.dart';
import 'package:keel_ui/src/integrations/keel_node/keel_node.dart';
import 'package:keel_ui/src/modules/keel_remote/model/desktop_node_state.dart';
import 'package:keel_ui/src/modules/keel_remote/repository/keel_nodes_repository.dart';

/// This PC as a keel-api node (`kind: desktop`): connecting it with the
/// person's session, the node running with its own token, and disconnecting
/// it.
///
/// Connecting enrolls `<hostname>-desktop` with the signed-in session and
/// keeps the `knt_` token it answers in the owner-only node file; from then
/// on the node runs with that token, not with the person's session, and
/// starts again by itself with the app ([resume]). Only the main window
/// runs it.
class DesktopNodeViewModel extends ViewModel<DesktopNodeState> {
  DesktopNodeViewModel() : super(const DesktopNodeState());

  /// How many of the link's lines the panel shows.
  static const int recentLines = 8;

  KeelNodesRepository get _nodes => const KeelNodesRepository();
  KeelNodeCredentialsStore get _store =>
      KeelApiService.nodeCredentials.notifier;
  KeelApiClient get _client => KeelApiService.client.notifier;

  DesktopNodeRuntime? _runtime;
  bool _resumed = false;
  bool _refreshQueued = false;

  @override
  void init() {}

  /// Starts the node kept from before, once, at startup. Without a node file
  /// this PC is not a node, and nothing happens.
  Future<void> resume() async {
    if (_resumed) return;
    _resumed = true;
    final credentials = await _store.read();
    if (credentials == null || isDisposed) return;
    await _start(credentials);
  }

  /// Enrolls this PC with the signed-in session and starts the node.
  Future<void> connect() async {
    if (!data.canConnect) return;
    final origin = _client.origin;
    if (origin.isEmpty) {
      updateState(
        const DesktopNodeState(
          failure: KeelApiFailure(kind: KeelApiFailureKind.notSignedIn),
        ),
      );
      return;
    }
    final hostname = Platform.localHostname;
    final nodeId = DesktopNodeIdentity.idFor(hostname);
    updateState(
      DesktopNodeState(status: DesktopNodeStatus.connecting, nodeId: nodeId),
    );
    final enrolled = await _nodes.enrollDesktop(
      id: nodeId,
      label: DesktopNodeIdentity.labelFor(hostname),
    );
    if (isDisposed) return;
    switch (enrolled) {
      case Err(:final error):
        updateState(DesktopNodeState(failure: error));
      case Ok(data: final enrollment):
        final credentials = KeelNodeCredentials(
          origin: origin,
          nodeId: enrollment.id.isEmpty ? nodeId : enrollment.id,
          token: enrollment.token,
        );
        if (!credentials.isComplete) {
          await _nodes.unlink(credentials.nodeId);
          updateState(
            const DesktopNodeState(
              failure: KeelApiFailure(kind: KeelApiFailureKind.unexpected),
            ),
          );
          return;
        }
        if (!await _store.write(credentials)) {
          // A token that cannot be kept owner-only is not kept at all, and
          // the node it opened is unlinked again.
          await _nodes.unlink(credentials.nodeId);
          updateState(
            const DesktopNodeState(problem: DesktopNodeProblem.tokenNotStored),
          );
          return;
        }
        await _start(credentials);
    }
  }

  /// Stops the node, unlinks it with the person's session and forgets its
  /// token. This PC stops taking tasks whatever the server answers: a
  /// server that did not confirm is said, and the token it still lists
  /// is held by nobody.
  Future<void> disconnect() async {
    if (!data.canDisconnect) return;
    final nodeId = data.nodeId;
    updateState(
      data.copyWith(
        status: DesktopNodeStatus.disconnecting,
        clearFailure: true,
        clearProblem: true,
      ),
    );
    final runtime = _runtime;
    _runtime = null;
    await runtime?.stop();
    final unlinked = await _nodes.unlink(nodeId);
    await _store.clear();
    if (isDisposed) return;
    final failure = unlinked.whenError(
      (failure) => failure.kind == KeelApiFailureKind.notFound ? null : failure,
    );
    updateState(
      DesktopNodeState(
        failure: failure,
        problem: failure == null ? null : DesktopNodeProblem.unlinkNotConfirmed,
      ),
    );
  }

  /// Stops the node as the app quits, keeping it connected: it starts again
  /// with the app, and resumes reporting the tasks it followed.
  Future<void> stopOnQuit() async {
    final runtime = _runtime;
    _runtime = null;
    await runtime?.stop();
  }

  Future<void> _start(KeelNodeCredentials credentials) async {
    final runtime = DesktopNodeRuntime(
      credentials: credentials,
      log: NodeMemoryLog(onChange: _queueRefresh),
    );
    _runtime = runtime;
    updateState(
      DesktopNodeState(
        status: DesktopNodeStatus.connecting,
        nodeId: credentials.nodeId,
      ),
    );
    final started = await runtime.start();
    if (!identical(_runtime, runtime) || isDisposed) return;
    started.when(
      ok: (_) {
        updateState(
          DesktopNodeState(
            status: DesktopNodeStatus.on,
            nodeId: credentials.nodeId,
          ),
        );
        _refresh();
      },
      err: (why) {
        Log.e('keel_node: the node did not start: $why');
        _runtime = null;
        updateState(
          DesktopNodeState(
            status: DesktopNodeStatus.failed,
            nodeId: credentials.nodeId,
            problem: DesktopNodeProblem.notStarted,
          ),
        );
      },
    );
  }

  /// One refresh after the line just written: keel-core keeps a call's
  /// outcome right after writing its line, so the refresh runs once both
  /// are there, and lines written together refresh once.
  void _queueRefresh() {
    if (_refreshQueued) return;
    _refreshQueued = true;
    scheduleMicrotask(() {
      _refreshQueued = false;
      _refresh();
    });
  }

  void _refresh() {
    final runtime = _runtime;
    if (runtime == null || isDisposed || !data.isOn) return;
    final calls = runtime.calls;
    transformState(
      (state) => state.copyWith(
        lastPoll: _callOf(calls[DesktopNodeRuntime.pollEndpoint]),
        lastReport: _callOf(calls[DesktopNodeRuntime.statusEndpoint]),
        tasksTaken: runtime.log.tasksTaken,
        recent: [
          for (final line in runtime.log.tail(recentLines))
            DesktopNodeLogLine(
              at: line.at,
              level: line.level,
              title: line.title,
              count: line.count,
            ),
        ],
      ),
    );
  }

  static DesktopNodeCall? _callOf(
    ({DateTime at, bool ok, String outcome})? record,
  ) => switch (record) {
    (:final at, :final ok, :final outcome) => DesktopNodeCall(
      at: at,
      ok: ok,
      outcome: outcome,
    ),
    null => null,
  };
}

mixin DesktopNodeService {
  static final ReactiveNotifier<DesktopNodeViewModel> instance =
      ReactiveNotifier<DesktopNodeViewModel>(DesktopNodeViewModel.new);
}
