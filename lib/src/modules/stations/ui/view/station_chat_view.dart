import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/fade_in_entrance.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/permission_request_banner.dart';
import 'package:keel_ui/src/modules/stations/model/member_color.dart';
import 'package:keel_ui/src/modules/stations/model/station.dart';
import 'package:keel_ui/src/modules/stations/model/station_task.dart';
import 'package:keel_ui/src/modules/stations/model/thread_entry.dart';
import 'package:keel_ui/src/modules/stations/ui/view/station_map_view.dart';
import 'package:keel_ui/src/modules/stations/ui/widget/station_live_turn_strip.dart';
import 'package:keel_ui/src/modules/stations/ui/widget/station_message_bubble.dart';
import 'package:keel_ui/src/modules/stations/ui/widget/workflow_progress_panel.dart';
import 'package:keel_ui/src/modules/stations/viewmodel/stations_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';
import 'package:keel_ui/src/shared/shared.dart';

/// What the channel is showing: the conversation, or the same conversation
/// drawn as a network.
enum StationTab { chat, map }

/// The channel: one shared thread where every member of the station writes,
/// with the running workflow beside it.
class StationChatView extends StatefulWidget {
  const StationChatView({super.key, required this.station});

  final Station station;

  @override
  State<StationChatView> createState() => _StationChatViewState();
}

class _StationChatViewState extends State<StationChatView> {
  StationTab _tab = StationTab.chat;

  /// Subscribes to the two catalogues the channel depends on. Reading them
  /// straight off their singletons instead — which is what this used to do —
  /// means the channel renders before they finish loading and never rebuilds:
  /// no author names, no colours, no step chips, and a panel claiming the
  /// station has no workflow.
  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<AgentProfilesViewModel, AgentProfilesState>(
      viewmodel: AgentProfilesService.instance.notifier,
      build: (profilesState, profilesViewModel, keepProfiles) {
        return ReactiveViewModelBuilder<WorkflowsViewModel, WorkflowsState>(
          viewmodel: WorkflowsService.instance.notifier,
          build: (workflowsState, workflowsViewModel, keepWorkflows) {
            final stations = StationsService.instance.notifier;
            return _StationChannel(
              station: widget.station,
              members: stations.membersOf(widget.station),
              allProfiles: profilesState.profiles,
              workflow: stations.activeWorkflowOf(widget.station),
              tab: _tab,
              onTabChanged: (tab) => setState(() => _tab = tab),
            );
          },
        );
      },
    );
  }
}

class _StationChannel extends StatelessWidget {
  const _StationChannel({
    required this.station,
    required this.members,
    required this.allProfiles,
    required this.workflow,
    required this.tab,
    required this.onTabChanged,
  });

  final Station station;
  final List<AgentProfile> members;
  final List<AgentProfile> allProfiles;
  final Workflow? workflow;
  final StationTab tab;
  final ValueChanged<StationTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final task = station.activeTask;
    final running = task?.isRunning ?? false;
    final pendingPermission = task?.pendingPermission;
    final liveTurn = task?.liveTurn;

    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _ChannelHeader(
                station: station,
                task: task,
                members: members,
                workflow: workflow,
                tab: tab,
                onTabChanged: onTabChanged,
              ),
              const Divider(height: 1),
              Expanded(
                child: switch (tab) {
                  StationTab.chat => _ThreadList(
                    stationId: station.id,
                    task: task,
                    members: members,
                    allProfiles: allProfiles,
                    workflow: workflow,
                  ),
                  StationTab.map => StationMapView(
                    task: task,
                    members: members,
                    workflow: workflow,
                  ),
                },
              ),
              if (tab == StationTab.chat && liveTurn != null)
                StationLiveTurnStrip(turn: liveTurn, members: members),
              if (tab == StationTab.chat &&
                  task != null &&
                  pendingPermission != null)
                PermissionRequestBanner(
                  request: pendingPermission,
                  busy: running,
                  onRespond: (grant) =>
                      StationsService.instance.notifier.respondToTaskPermission(
                        station.id,
                        task.id,
                        grant: grant,
                      ),
                ),
              SizedBox(
                height: 2,
                child: running
                    ? const LinearProgressIndicator(minHeight: 2)
                    : Divider(
                        height: 2,
                        thickness: 1,
                        color: Theme.of(context).dividerColor,
                      ),
              ),
              if (tab == StationTab.chat)
                _Composer(station: station, task: task),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 272,
          child: WorkflowProgressPanel(
            station: station,
            task: task,
            workflow: workflow,
            members: members,
          ),
        ),
      ],
    );
  }
}

/// The thread itself: messages interleaved with the hand-off dividers that
/// explain why the speaker changed.
class _ThreadList extends StatelessWidget {
  const _ThreadList({
    required this.stationId,
    required this.task,
    required this.members,
    required this.allProfiles,
    required this.workflow,
  });

  final String stationId;
  final StationTask? task;
  final List<AgentProfile> members;
  final List<AgentProfile> allProfiles;
  final Workflow? workflow;

  @override
  Widget build(BuildContext context) {
    final open = task;
    if (open == null) return _EmptyChannel(stationId: stationId);

    final entries = buildThreadEntries(
      messages: open.messages,
      workflow: workflow,
    );

    return SelectionArea(
      child: ListView.builder(
        reverse: true,
        padding: const EdgeInsets.all(16),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[entries.length - 1 - index];
          return switch (entry) {
            ThreadHandoff(label: final label) => _HandoffDivider(label: label),
            ThreadMessage(message: final message) => _ThreadBubble(
              key: ValueKey(message.timestamp.microsecondsSinceEpoch),
              stationId: stationId,
              message: message,
              members: members,
              allProfiles: allProfiles,
              workflow: workflow,
            ),
          };
        },
      ),
    );
  }
}

class _ThreadBubble extends StatelessWidget {
  const _ThreadBubble({
    super.key,
    required this.stationId,
    required this.message,
    required this.members,
    required this.allProfiles,
    required this.workflow,
  });

  final String stationId;
  final ChatMessage message;
  final List<AgentProfile> members;

  /// Every registered profile, not just this station's members: a message
  /// keeps naming its author even after that agent is removed from the
  /// station. Resolving only against members is what made older messages lose
  /// their author line entirely.
  final List<AgentProfile> allProfiles;
  final Workflow? workflow;

  AgentProfile? _profileById(String? id) {
    if (id == null) return null;
    return allProfiles.where((p) => p.id == id).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final author = _profileById(message.authorProfileId);
    final askedBy = _profileById(message.consultOfProfileId);
    final stepIndex = message.stepIndex;
    final steps = workflow?.steps ?? const [];
    final stepTitle = (stepIndex != null && stepIndex < steps.length)
        ? 'paso ${stepIndex + 1} · ${steps[stepIndex].title}'
        : null;
    final memberIds = [for (final member in members) member.id];

    return FadeInEntrance(
      child: StationMessageBubble(
        message: message,
        stationId: stationId,
        author: author,
        stepTitle: stepTitle,
        askedBy: askedBy,
        memberIndex: author == null
            ? 0
            : authorPaletteIndex(author.id, memberIds),
        askedByIndex: askedBy == null
            ? 0
            : authorPaletteIndex(askedBy.id, memberIds),
      ),
    );
  }
}

/// The thin rule that marks where the work changed hands — a hair-line on
/// each side of a small monospace label, so it reads as punctuation in the
/// thread rather than as another message.
class _HandoffDivider extends StatelessWidget {
  const _HandoffDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(height: 1, color: scheme.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                letterSpacing: 0.4,
                color: scheme.outline,
              ),
            ),
          ),
          Expanded(child: Divider(height: 1, color: scheme.outlineVariant)),
        ],
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({required this.station, required this.task});

  final Station station;
  final StationTask? task;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    if (widget.task?.isRunning ?? false) return;
    StationsService.instance.notifier.sendToChannel(widget.station.id, text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final station = widget.station;
    final task = widget.task;
    final running = task?.isRunning ?? false;
    final started =
        task?.messages.any((m) => m.role == ChatRole.assistant) ?? false;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: ShapeDecoration(
                    shape: 16.smoothBorder(
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    enabled: task != null && !running,
                    decoration: InputDecoration(
                      hintText: switch (task) {
                        null => 'Creá una tarea para empezar',
                        _ when !started =>
                          'Qué necesitás en esta tarea de #${station.name}',
                        _ => 'Mensaje a #${station.name}',
                      },
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: running ? 'Detener' : 'Enviar',
                onPressed: switch ((running, task)) {
                  (true, final open?) =>
                    () => StationsService.instance.notifier.stopTask(
                      station.id,
                      open.id,
                    ),
                  (false, final _?) => _send,
                  _ => null,
                },
                icon: Icon(running ? Icons.stop_circle : Icons.send),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(switch (task) {
              null => 'Las tareas se crean con el botón "Nueva tarea".',
              _ when !started =>
                'Arranca el workflow de la estación en esta tarea.',
              _ =>
                'El workflow reparte los pasos. Escribí cuando quieras '
                    'corregir el rumbo — entra en el paso que esté corriendo.',
            }, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _ChannelHeader extends StatelessWidget {
  const _ChannelHeader({
    required this.station,
    required this.task,
    required this.members,
    required this.workflow,
    required this.tab,
    required this.onTabChanged,
  });

  final Station station;
  final StationTask? task;
  final List<AgentProfile> members;
  final Workflow? workflow;
  final StationTab tab;
  final ValueChanged<StationTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final open = task;
    String subtitle;
    if (open == null) {
      subtitle = station.purpose.isEmpty
          ? 'Sin tarea abierta'
          : station.purpose;
    } else {
      subtitle = [
        'Tarea: ${open.title}',
        if (workflow != null) workflow!.name,
        if (open.contextUsageRatio != null)
          'contexto ${(open.contextUsageRatio! * 100).round()}%',
      ].join(' · ');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '#',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      station.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          SegmentedButton<StationTab>(
            segments: const [
              ButtonSegment(
                value: StationTab.chat,
                icon: Icon(Icons.forum_outlined, size: 16),
                label: Text('Chat'),
              ),
              ButtonSegment(
                value: StationTab.map,
                icon: Icon(Icons.hub_outlined, size: 16),
                label: Text('Mapa'),
              ),
            ],
            selected: {tab},
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            onSelectionChanged: (values) => onTabChanged(values.first),
          ),
          const SizedBox(width: 12),
          _Facepile(members: members),
          const SizedBox(width: 8),
          Text(
            '${members.length}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// The station's members as overlapping colour chips — who is in the room,
/// readable at a glance instead of as a bare count.
class _Facepile extends StatelessWidget {
  const _Facepile({required this.members});

  final List<AgentProfile> members;

  static const _maxShown = 5;

  static const _size = 24.0;
  static const _step = 17.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = members.take(_maxShown).toList();
    final overflow = members.length - shown.length;
    if (shown.isEmpty) return const SizedBox.shrink();

    // Overlapping avatars are laid out in a Stack, not with negative margins —
    // Container asserts on those.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _size + (shown.length - 1) * _step,
          height: _size,
          child: Stack(
            children: [
              for (var index = 0; index < shown.length; index++)
                Positioned(
                  left: index * _step,
                  child: Tooltip(
                    message: shown[index].role.isEmpty
                        ? shown[index].name
                        : '${shown[index].name} · ${shown[index].role}',
                    child: Container(
                      width: _size,
                      height: _size,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: scheme.surface, width: 1.5),
                      ),
                      child: Icon(
                        Icons.smart_toy,
                        size: 14,
                        color: memberColorFor(index),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (overflow > 0)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              '+$overflow',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _EmptyChannel extends StatelessWidget {
  const _EmptyChannel({required this.stationId});

  final String stationId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 36,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'Ninguna tarea abierta',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Cada tarea es un entorno aparte: su propio hilo y su propio '
              'contexto, con toda la configuración de esta estación.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  StationsService.instance.notifier.createTask(stationId),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nueva tarea'),
            ),
          ],
        ),
      ),
    );
  }
}
