import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_core/core/services/external_link_service.dart';
import 'package:keel_core/modules/agents/model/chat_message.dart';
import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_notice_bubble.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/markdown_text.dart';
import 'package:keel_ui/src/modules/keel_remote/model/remote_task.dart';
import 'package:keel_ui/src/modules/keel_remote/model/remote_tasks_state.dart';
import 'package:keel_ui/src/modules/keel_remote/ui/keel_remote_presentation.dart';
import 'package:keel_ui/src/modules/keel_remote/ui/widget/keel_remote_parts.dart';
import 'package:keel_ui/src/modules/keel_remote/viewmodel/remote_task_viewmodel.dart';

/// The central area following one task of the Keel API: its status, its
/// result and what the node reported, read again every few seconds while it
/// runs.
class RemoteTaskView extends StatefulWidget {
  const RemoteTaskView({super.key});

  @override
  State<RemoteTaskView> createState() => _RemoteTaskViewState();
}

class _RemoteTaskViewState extends State<RemoteTaskView> {
  @override
  void initState() {
    super.initState();
    RemoteTaskService.instance.notifier.watch();
  }

  @override
  void dispose() {
    RemoteTaskService.instance.notifier.unwatch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<RemoteTaskViewModel, RemoteTaskFollowState>(
      viewmodel: RemoteTaskService.instance.notifier,
      build: (state, viewmodel, keep) {
        final task = state.task;
        final failure = state.failure;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RemoteTaskHeader(state: state),
            KeelLoadingBar(loading: state.loading),
            const Divider(height: 1),
            Expanded(
              child: SelectionArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  children: [
                    if (failure != null) KeelFailureText(failure: failure),
                    if (task != null) ...[
                      _RemoteTaskResultSection(task: task),
                      _RemoteTaskEvents(events: state.events),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RemoteTaskHeader extends StatelessWidget {
  const _RemoteTaskHeader({required this.state});

  final RemoteTaskFollowState state;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final task = state.task;
    final viewmodel = RemoteTaskService.instance.notifier;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
      child: Row(
        children: [
          const Icon(Icons.cloud_outlined, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task?.type ?? state.taskId ?? '',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
                if (task != null)
                  Text(
                    task.detailLine(t, DateTime.now()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: t.keelApiRefresh,
            onPressed: viewmodel.refresh,
            icon: const Icon(Icons.refresh, size: 18),
          ),
          if (task != null && task.canCancel)
            TextButton.icon(
              onPressed: viewmodel.cancel,
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: Text(t.keelApiCancelTask),
            ),
        ],
      ),
    );
  }
}

/// What the node closed the task with: its report, its error, its PR.
class _RemoteTaskResultSection extends StatelessWidget {
  const _RemoteTaskResultSection({required this.task});

  final RemoteTask task;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final result = task.result;
    if (result == null) return const SizedBox.shrink();
    final report = task.report;
    final error = result.error;
    final prUrl = result.prUrl;
    final step = task.liveStep;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KeelSectionTitle(text: t.keelApiTaskSummary),
        if (step != null) Text(step, style: TextStyle(color: scheme.outline)),
        if (report != null) MarkdownText(report, color: scheme.onSurface),
        if (error != null)
          ChatNoticeBubble(role: ChatRole.error, text: error, fontSize: 13),
        if (prUrl != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: () => openExternalUrl(prUrl),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(prUrl),
            ),
          ),
      ],
    );
  }
}

/// The task's history, oldest first, each entry read as Markdown.
class _RemoteTaskEvents extends StatelessWidget {
  const _RemoteTaskEvents({required this.events});

  final List<RemoteTaskEvent> events;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeelSectionTitle(text: t.keelApiTaskEvents),
        if (events.isEmpty) KeelEmptyText(text: t.keelApiTaskNoEvents),
        for (final event in events)
          _RemoteTaskEventEntry(event: event, now: now),
      ],
    );
  }
}

class _RemoteTaskEventEntry extends StatelessWidget {
  const _RemoteTaskEventEntry({required this.event, required this.now});

  final RemoteTaskEvent event;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = event.markdown;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.headerLine(t, now),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10.5,
              color: scheme.outline,
            ),
          ),
          if (body.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            MarkdownText(body, color: scheme.onSurface, fontSize: 13.5),
          ],
        ],
      ),
    );
  }
}
