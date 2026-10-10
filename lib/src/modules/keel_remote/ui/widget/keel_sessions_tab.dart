import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/modules/keel_remote/model/live_session.dart';
import 'package:keel_ui/src/modules/keel_remote/ui/keel_remote_presentation.dart';
import 'package:keel_ui/src/modules/keel_remote/ui/widget/keel_remote_parts.dart';
import 'package:keel_ui/src/modules/keel_remote/viewmodel/live_sessions_viewmodel.dart';
import 'package:keel_ui/src/modules/workspace/viewmodel/workspace_viewmodel.dart';

/// «Sesiones»: what every node reports it is running, grouped the way
/// keel-bot groups it — what waits on you, the active sessions, other work,
/// and what ended.
class KeelSessionsTab extends StatefulWidget {
  const KeelSessionsTab({super.key});

  @override
  State<KeelSessionsTab> createState() => _KeelSessionsTabState();
}

class _KeelSessionsTabState extends State<KeelSessionsTab> {
  @override
  void initState() {
    super.initState();
    LiveSessionsService.instance.notifier.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ReactiveViewModelBuilder<LiveSessionsViewModel, LiveSessionsState>(
      viewmodel: LiveSessionsService.instance.notifier,
      build: (state, viewmodel, keep) {
        final failure = state.failure;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KeelTabToolbar(onRefresh: viewmodel.refresh),
            KeelLoadingBar(loading: state.loading),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  if (failure != null) KeelFailureText(failure: failure),
                  if (state.sessions.isEmpty && !state.loading)
                    KeelEmptyText(text: t.keelApiSessionsEmpty),
                  for (final (group, members) in state.groups) ...[
                    KeelSectionTitle(text: group.title(t)),
                    for (final session in members)
                      _LiveSessionTile(session: session),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LiveSessionTile extends StatelessWidget {
  const _LiveSessionTile({required this.session});

  final LiveSession session;

  /// A session started by a task opens that task; Keel AI answering opens
  /// the chat with that node. Other work has nothing more to show here.
  VoidCallback? _opener(BuildContext context) {
    final taskId = session.followedTaskId;
    if (taskId != null) {
      return () {
        Navigator.of(context).pop();
        WorkspaceService.instance.notifier.openRemoteTask(taskId);
      };
    }
    if (session.kind == LiveSessionKind.keelAi) {
      return () {
        Navigator.of(context).pop();
        WorkspaceService.instance.notifier.openServerChat(session.nodeId);
      };
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
      onTap: _opener(context),
      leading: Icon(
        session.waitingOnYou
            ? Icons.front_hand_outlined
            : Icons.play_circle_outline,
        size: 20,
        color: session.waitingOnYou ? scheme.tertiary : null,
      ),
      title: Text(session.label),
      subtitle: Text(session.detailLine(t)),
      trailing: Text(
        session.status,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: scheme.outline,
        ),
      ),
    );
  }
}
