/// How the Keel API's data reads on screen: every word comes from the ARB
/// catalogs, and every decision of wording lives here instead of inside a
/// `build()`.
library;

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/integrations/keel_api/keel_api.dart';
import 'package:keel_ui/src/modules/keel_remote/model/desktop_node_state.dart';
import 'package:keel_ui/src/modules/keel_remote/model/keel_account_state.dart';
import 'package:keel_ui/src/modules/keel_remote/model/keel_node.dart';
import 'package:keel_ui/src/modules/keel_remote/model/live_session.dart';
import 'package:keel_ui/src/modules/keel_remote/model/remote_task.dart';
import 'package:keel_ui/src/modules/keel_remote/model/server_chat.dart';

extension KeelApiFailureText on KeelApiFailure {
  /// The failure in words, with what the server or the node said under it.
  String message(AppLocalizations t) {
    final base = switch (kind) {
      KeelApiFailureKind.notSignedIn => t.keelApiFailureNotSignedIn,
      KeelApiFailureKind.invalidServer => t.keelApiFailureInvalidServer,
      KeelApiFailureKind.unauthorized => t.keelApiFailureUnauthorized,
      KeelApiFailureKind.forbidden => t.keelApiFailureForbidden,
      KeelApiFailureKind.badRequest => t.keelApiFailureBadRequest,
      KeelApiFailureKind.notFound => t.keelApiFailureNotFound,
      KeelApiFailureKind.conflict => t.keelApiFailureConflict,
      KeelApiFailureKind.rateLimited => t.keelApiFailureRateLimited,
      KeelApiFailureKind.server => t.keelApiFailureServer,
      KeelApiFailureKind.network => t.keelApiFailureNetwork,
      KeelApiFailureKind.unexpected => t.keelApiFailureUnexpected,
      KeelApiFailureKind.noOnlineNode => t.keelApiFailureNoOnlineNode,
      KeelApiFailureKind.stalled => t.keelApiFailureStalled,
      KeelApiFailureKind.nodeFailed => t.keelApiFailureNodeFailed,
      KeelApiFailureKind.storage => t.keelApiFailureStorage,
    };
    final detail = serverMessage?.trim();
    return detail == null || detail.isEmpty ? base : '$base\n\n$detail';
  }
}

extension KeelAccountStateText on KeelAccountState {
  /// What the rail button says about the connection.
  String railTooltip(AppLocalizations t) => switch (connection) {
    KeelConnection.off => t.keelApiRailTooltipOff,
    KeelConnection.connected => t.keelApiRailTooltipConnected(host, username),
    KeelConnection.ended => t.keelApiRailTooltipEnded,
  };
}

extension RemoteTaskStatusText on RemoteTaskStatus {
  String label(AppLocalizations t) => switch (this) {
    RemoteTaskStatus.todo => t.keelApiStatusTodo,
    RemoteTaskStatus.evaluating => t.keelApiStatusEvaluating,
    RemoteTaskStatus.inProgress => t.keelApiStatusInProgress,
    RemoteTaskStatus.paused => t.keelApiStatusPaused,
    RemoteTaskStatus.done => t.keelApiStatusDone,
    RemoteTaskStatus.cancelled => t.keelApiStatusCancelled,
  };
}

extension RemoteTaskText on RemoteTask {
  /// What the node closed the task with: its report, or Keel AI's answer.
  String? get report => switch (result?.summary ?? result?.reply) {
    final String text when text.trim().isNotEmpty => text,
    _ => null,
  };

  /// The step the node is on, while it still works.
  String? get liveStep => isTerminal ? null : result?.step;

  /// `En curso · hp-server · keel-api · 18:42`.
  String detailLine(AppLocalizations t, DateTime now) => <String?>[
    status.label(t),
    placedOn ?? t.keelApiAnyNode,
    project,
    createdAt?.stamp(now),
  ].whereType<String>().join(' · ');
}

extension RemoteTaskDraftProblemText on RemoteTaskDraftProblem {
  String message(AppLocalizations t) => switch (this) {
    RemoteTaskDraftProblem.missingType => t.keelApiDraftMissingType,
    RemoteTaskDraftProblem.payloadNotObject => t.keelApiDraftPayloadNotObject,
    RemoteTaskDraftProblem.nodeNotOnline => t.keelApiDraftNodeNotOnline,
  };
}

extension RemoteTaskEventText on RemoteTaskEvent {
  /// The person writes messages as `user`.
  static const String _personAuthor = 'user';

  /// Who or what the entry is.
  String writer(AppLocalizations t) => switch (kind) {
    'message' => switch (author) {
      _personAuthor => t.keelApiEventYou,
      final String name => name,
      null => t.keelApiEventMessage,
    },
    'step' => t.keelApiEventStep,
    'decision.opened' => t.keelApiEventDecisionOpened,
    'decision.answered' => t.keelApiEventDecisionAnswered,
    'action.applied' => t.keelApiEventActionApplied,
    'action.failed' => t.keelApiEventActionFailed,
    final String other => other,
  };

  /// `Paso · 18:42`.
  String headerLine(AppLocalizations t, DateTime now) =>
      [writer(t), ?createdAt?.stamp(now)].join(' · ');

  /// The entry as Markdown.
  String get markdown => switch (kind) {
    'message' => text ?? '',
    'step' => <String?>[
      stepTitle,
      stepState,
      detail,
    ].whereType<String>().join(' · '),
    'decision.opened' => <String>[
      ?question,
      for (final option in options) '- `$option`',
    ].join('\n'),
    'decision.answered' => <String>[
      ?question,
      if (answer case final String chosen) '→ `$chosen`',
    ].join('\n\n'),
    'action.applied' => detail ?? '',
    'action.failed' => error ?? '',
    _ => '```json\n$rawPayload\n```',
  };
}

extension KeelNodeText on KeelNode {
  /// `keel-server · en línea`, or with when it was last seen.
  String statusLine(AppLocalizations t, DateTime now) => <String?>[
    displayKind,
    online ? t.keelApiNodeOnline : t.keelApiNodeOffline,
    if (!online)
      switch (lastSeenAt) {
        final DateTime seen => t.keelApiNodeLastSeen(seen.stamp(now)),
        null => null,
      },
  ].whereType<String>().join(' · ');
}

extension LiveSessionKindText on LiveSessionKind {
  String label(AppLocalizations t) => switch (this) {
    LiveSessionKind.session => t.keelApiKindSession,
    LiveSessionKind.keelAi => t.keelApiKindKeelAi,
    LiveSessionKind.launch => t.keelApiKindLaunch,
    LiveSessionKind.deploy => t.keelApiKindDeploy,
    LiveSessionKind.job => t.keelApiKindJob,
    LiveSessionKind.tool => t.keelApiKindTool,
    LiveSessionKind.clone => t.keelApiKindClone,
    LiveSessionKind.work => t.keelApiKindWork,
  };
}

extension LiveSessionGroupText on LiveSessionGroup {
  String title(AppLocalizations t) => switch (this) {
    LiveSessionGroup.waiting => t.keelApiGroupWaiting,
    LiveSessionGroup.active => t.keelApiGroupActive,
    LiveSessionGroup.work => t.keelApiGroupWork,
    LiveSessionGroup.finished => t.keelApiGroupFinished,
  };
}

extension LiveSessionText on LiveSession {
  /// `Sesión · hp-server · Implementación · aprueba solo`.
  String detailLine(AppLocalizations t) => <String?>[
    kind.label(t),
    nodeId,
    step.trim().isEmpty ? null : step.trim(),
    autoApprove ? t.keelApiAutoApprove : null,
  ].whereType<String>().join(' · ');
}

extension ServerChatStateText on ServerChatState {
  /// `Keel AI está respondiendo… · leyendo el repo`.
  String progressLine(AppLocalizations t) => switch (step) {
    final String current => '${t.keelApiChatAnswering} · $current',
    null => t.keelApiChatAnswering,
  };
}

extension DesktopNodeStatusText on DesktopNodeStatus {
  String label(AppLocalizations t) => switch (this) {
    DesktopNodeStatus.off => t.keelThisPcStatusOff,
    DesktopNodeStatus.connecting => t.keelThisPcStatusConnecting,
    DesktopNodeStatus.on => t.keelThisPcStatusOn,
    DesktopNodeStatus.failed => t.keelThisPcStatusFailed,
    DesktopNodeStatus.disconnecting => t.keelThisPcStatusDisconnecting,
  };
}

extension DesktopNodeProblemText on DesktopNodeProblem {
  String message(AppLocalizations t) => switch (this) {
    DesktopNodeProblem.tokenNotStored => t.keelThisPcProblemTokenNotStored,
    DesktopNodeProblem.notStarted => t.keelThisPcProblemNotStarted,
    DesktopNodeProblem.unlinkNotConfirmed =>
      t.keelThisPcProblemUnlinkNotConfirmed,
  };
}

extension DesktopNodeStateText on DesktopNodeState {
  /// Whether the Account tab shows the node: always while signed in, and
  /// while this PC is a node — or just stopped being one — so it can always
  /// be stopped and what happened is read.
  bool shownWith({required bool signedIn}) =>
      signedIn ||
      status != DesktopNodeStatus.off ||
      problem != null ||
      failure != null;

  /// `Última consulta de tareas: HTTP 200 · 18:42`.
  String pollLine(AppLocalizations t, DateTime now) =>
      t.keelThisPcLastPoll(_callText(lastPoll, t, now));

  /// `Último reporte de estado: HTTP 200 · 18:42`.
  String reportLine(AppLocalizations t, DateTime now) =>
      t.keelThisPcLastReport(_callText(lastReport, t, now));

  /// Whether the Keel app can chat with Keel AI on this PC.
  String keelAiLine(AppLocalizations t) =>
      keelAi ? t.keelThisPcKeelAiOn : t.keelThisPcKeelAiOff;

  static String _callText(
    DesktopNodeCall? call,
    AppLocalizations t,
    DateTime now,
  ) => switch (call) {
    final DesktopNodeCall made => '${made.outcome} · ${made.at.stamp(now)}',
    null => t.keelThisPcNotYet,
  };
}

extension DesktopNodeAutoApprovalText on DesktopNodeAutoApproval {
  /// `keel-ui › Fix the login`.
  String get label => '$project › $title';
}

extension DesktopNodeLogLineText on DesktopNodeLogLine {
  /// `18:42  GET tasks/pending → HTTP 200 · 0 tasks  ×12`.
  String line(DateTime now) =>
      '${at.stamp(now)}  $title${count > 1 ? '  ×$count' : ''}';
}

extension KeelStamp on DateTime {
  /// `18:42` on the day of [now], `09/10 18:42` any other day.
  String stamp(DateTime now) {
    String two(int value) => value.toString().padLeft(2, '0');
    final clock = '${two(hour)}:${two(minute)}';
    return (year, month, day) == (now.year, now.month, now.day)
        ? clock
        : '${two(day)}/${two(month)} $clock';
  }
}
