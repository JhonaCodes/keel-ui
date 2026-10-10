import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/modules/keel_remote/model/remote_task.dart';
import 'package:keel_ui/src/modules/keel_remote/model/remote_tasks_state.dart';
import 'package:keel_ui/src/modules/keel_remote/ui/keel_remote_presentation.dart';
import 'package:keel_ui/src/modules/keel_remote/ui/screen/new_remote_task_form.dart';
import 'package:keel_ui/src/modules/keel_remote/ui/widget/keel_remote_parts.dart';
import 'package:keel_ui/src/modules/keel_remote/viewmodel/keel_nodes_viewmodel.dart';
import 'package:keel_ui/src/modules/keel_remote/viewmodel/remote_tasks_viewmodel.dart';
import 'package:keel_ui/src/modules/workspace/viewmodel/workspace_viewmodel.dart';

/// «Tareas»: the queue, a status filter, «Nueva tarea», and a click to
/// follow one in the central area.
class KeelTasksTab extends StatefulWidget {
  const KeelTasksTab({super.key});

  @override
  State<KeelTasksTab> createState() => _KeelTasksTabState();
}

class _KeelTasksTabState extends State<KeelTasksTab> {
  @override
  void initState() {
    super.initState();
    RemoteTasksService.instance.notifier.refresh();
    // «Nueva tarea» only offers nodes online now.
    KeelNodesService.instance.notifier.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ReactiveViewModelBuilder<RemoteTasksViewModel, RemoteTasksState>(
      viewmodel: RemoteTasksService.instance.notifier,
      build: (state, viewmodel, keep) {
        final failure = state.failure;
        final now = DateTime.now();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KeelTabToolbar(
              onRefresh: viewmodel.refresh,
              leading: [_StatusFilter(selected: state.filter)],
              trailing: [
                FilledButton.tonalIcon(
                  onPressed: () => openNewRemoteTaskForm(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(t.keelApiNewTask),
                ),
                const SizedBox(width: 4),
              ],
            ),
            KeelLoadingBar(loading: state.loading),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                children: [
                  if (failure != null) KeelFailureText(failure: failure),
                  if (state.tasks.isEmpty && !state.loading)
                    KeelEmptyText(text: t.keelApiTasksEmpty),
                  for (final task in state.tasks)
                    _TaskTile(task: task, now: now),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.selected});

  final RemoteTaskStatus? selected;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return DropdownButton<RemoteTaskStatus?>(
      value: selected,
      underline: const SizedBox.shrink(),
      onChanged: RemoteTasksService.instance.notifier.filterBy,
      items: [
        DropdownMenuItem<RemoteTaskStatus?>(
          value: null,
          child: Text(t.keelApiFilterAll),
        ),
        for (final status in RemoteTaskStatus.values)
          DropdownMenuItem<RemoteTaskStatus?>(
            value: status,
            child: Text(status.label(t)),
          ),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.now});

  final RemoteTask task;
  final DateTime now;

  void _open(BuildContext context) {
    Navigator.of(context).pop();
    WorkspaceService.instance.notifier.openRemoteTask(task.id);
  }

  Future<void> _cancel(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final t = AppLocalizations.of(context);
    final failure = await RemoteTasksService.instance.notifier.cancel(task.id);
    if (failure == null) return;
    messenger.showSnackBar(SnackBar(content: Text(failure.message(t))));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
      onTap: () => _open(context),
      leading: Icon(
        task.isTerminal ? Icons.task_alt : Icons.pending_outlined,
        size: 20,
      ),
      title: Text(
        task.type,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
      subtitle: Text(task.detailLine(t, now)),
      trailing: task.canCancel
          ? IconButton(
              tooltip: t.keelApiCancelTask,
              onPressed: () => _cancel(context),
              icon: const Icon(Icons.cancel_outlined, size: 18),
            )
          : null,
    );
  }
}
