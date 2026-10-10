import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:result_controller/result_controller.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/integrations/keel_api/keel_api.dart';
import 'package:keel_ui/src/modules/keel_remote/model/keel_node.dart';
import 'package:keel_ui/src/modules/keel_remote/model/keel_nodes_state.dart';
import 'package:keel_ui/src/modules/keel_remote/model/remote_task.dart';
import 'package:keel_ui/src/modules/keel_remote/ui/keel_remote_presentation.dart';
import 'package:keel_ui/src/modules/keel_remote/ui/widget/keel_remote_parts.dart';
import 'package:keel_ui/src/modules/keel_remote/viewmodel/keel_nodes_viewmodel.dart';
import 'package:keel_ui/src/modules/keel_remote/viewmodel/remote_tasks_viewmodel.dart';

Future<void> openNewRemoteTaskForm(BuildContext context) {
  return showFormPanel<void>(context, child: const NewRemoteTaskForm());
}

/// «Nueva tarea»: a type, the online node it goes to, an optional project
/// and a JSON payload. Only nodes online now can be chosen.
class NewRemoteTaskForm extends StatefulWidget {
  const NewRemoteTaskForm({super.key});

  @override
  State<NewRemoteTaskForm> createState() => _NewRemoteTaskFormState();
}

class _NewRemoteTaskFormState extends State<NewRemoteTaskForm> {
  final _type = TextEditingController();
  final _project = TextEditingController();
  final _payload = TextEditingController(text: '{}');
  String? _nodeId;
  RemoteTaskDraftProblem? _problem;
  KeelApiFailure? _failure;
  bool _sending = false;

  @override
  void dispose() {
    _type.dispose();
    _project.dispose();
    _payload.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final tasks = RemoteTasksService.instance.notifier;
    final draft = RemoteTaskDraft(
      type: _type.text,
      nodeId: _nodeId,
      project: _project.text,
      payloadJson: _payload.text,
    );
    final problem = tasks.problemOf(draft);
    setState(() {
      _problem = problem;
      _failure = null;
      _sending = problem == null;
    });
    if (problem != null) return;
    final created = await tasks.create(draft);
    if (!mounted) return;
    switch (created) {
      case Ok():
        Navigator.of(context).pop();
      case Err(:final error):
        setState(() {
          _failure = error;
          _sending = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.keelApiNewTask)),
      body: ReactiveViewModelBuilder<KeelNodesViewModel, KeelNodesState>(
        viewmodel: KeelNodesService.instance.notifier,
        build: (nodes, viewmodel, keep) {
          final online = nodes.onlineWorkers;
          final chosen = nodes.byId(_nodeId);
          final problem = _problem;
          final failure = _failure;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextField(
                controller: _type,
                decoration: InputDecoration(
                  labelText: t.keelApiTaskTypeLabel,
                  hintText: t.keelApiTaskTypeHint,
                ),
              ),
              const SizedBox(height: 14),
              if (online.isEmpty)
                Text(
                  t.keelApiTaskNoOnlineNodes,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
              else
                DropdownButtonFormField<String>(
                  // A node that goes offline leaves the list: a new key
                  // rebuilds the field instead of keeping a value it no
                  // longer offers.
                  key: ValueKey(online.map((node) => node.id).join(',')),
                  initialValue: nodes.isOnlineWorker(_nodeId) ? _nodeId : null,
                  decoration: InputDecoration(
                    labelText: t.keelApiTaskNodeLabel,
                  ),
                  items: [
                    for (final node in online)
                      DropdownMenuItem<String>(
                        value: node.id,
                        child: Text(
                          '${node.displayName} · ${node.displayKind}',
                        ),
                      ),
                  ],
                  onChanged: (id) => setState(() => _nodeId = id),
                ),
              const SizedBox(height: 14),
              TextField(
                controller: _project,
                decoration: InputDecoration(
                  labelText: t.keelApiTaskProjectLabel,
                ),
              ),
              if (chosen != null && chosen.projects.isNotEmpty)
                _ProjectChoices(
                  node: chosen,
                  onPick: (name) => setState(() => _project.text = name),
                ),
              const SizedBox(height: 14),
              TextField(
                controller: _payload,
                minLines: 4,
                maxLines: 12,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: InputDecoration(
                  labelText: t.keelApiTaskPayloadLabel,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              KeelLoadingBar(loading: _sending),
              if (problem != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    problem.message(t),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (failure != null) KeelFailureText(failure: failure),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _sending || online.isEmpty ? null : _submit,
                  icon: const Icon(Icons.send, size: 16),
                  label: Text(t.keelApiTaskCreate),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The projects the chosen node reported, one click each.
class _ProjectChoices extends StatelessWidget {
  const _ProjectChoices({required this.node, required this.onPick});

  final KeelNode node;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final name in node.projects)
            ActionChip(label: Text(name), onPressed: () => onPick(name)),
        ],
      ),
    );
  }
}
