import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/services/external_link_service.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_composer_field.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/fade_in_entrance.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/permission_request_banner.dart';
import 'package:keel_ui/src/modules/projects/model/member_color.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/thread_entry.dart';
import 'package:keel_ui/src/modules/projects/ui/view/session_map_view.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/session_agent_picker.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/session_live_turn_strip.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/session_message_bubble.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/workflow_progress_panel.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';
import 'package:keel_ui/src/shared/shared.dart';

/// What the channel is showing: the conversation, or the same conversation
/// drawn as a network.
enum SessionTab { chat, map }

/// The channel: one shared thread where every member of the project writes,
/// with the running workflow beside it.
class SessionChatView extends StatefulWidget {
  const SessionChatView({super.key, required this.project});

  final Project project;

  @override
  State<SessionChatView> createState() => _SessionChatViewState();
}

class _SessionChatViewState extends State<SessionChatView> {
  SessionTab _tab = SessionTab.chat;

  /// Subscribes to the two catalogues the channel depends on. Reading them
  /// straight off their singletons instead — which is what this used to do —
  /// means the channel renders before they finish loading and never rebuilds:
  /// no author names, no colours, no step chips, and a panel claiming the
  /// project has no workflow.
  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<AgentProfilesViewModel, AgentProfilesState>(
      viewmodel: AgentProfilesService.instance.notifier,
      build: (profilesState, profilesViewModel, keepProfiles) {
        return ReactiveViewModelBuilder<WorkflowsViewModel, WorkflowsState>(
          viewmodel: WorkflowsService.instance.notifier,
          build: (workflowsState, workflowsViewModel, keepWorkflows) {
            final projects = ProjectsService.instance.notifier;
            return _ProjectChannel(
              project: widget.project,
              members: projects.membersOf(
                widget.project,
                session: widget.project.activeSession,
              ),
              allProfiles: profilesState.profiles,
              workflow: projects.activeWorkflowOf(widget.project),
              tab: _tab,
              onTabChanged: (tab) => setState(() => _tab = tab),
            );
          },
        );
      },
    );
  }
}

class _ProjectChannel extends StatelessWidget {
  const _ProjectChannel({
    required this.project,
    required this.members,
    required this.allProfiles,
    required this.workflow,
    required this.tab,
    required this.onTabChanged,
  });

  final Project project;
  final List<AgentProfile> members;
  final List<AgentProfile> allProfiles;
  final Workflow? workflow;
  final SessionTab tab;
  final ValueChanged<SessionTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final session = project.activeSession;
    final running = session?.isRunning ?? false;
    final pendingPermission = session?.pendingPermission;
    final liveTurn = session?.liveTurn;

    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _ChannelHeader(
                project: project,
                session: session,
                members: members,
                workflow: workflow,
                tab: tab,
                onTabChanged: onTabChanged,
              ),
              const Divider(height: 1),
              if (project.workingDirectory.trim().isEmpty)
                _MissingFolderBanner(projectId: project.id),
              Expanded(
                child: switch (tab) {
                  SessionTab.chat => _ThreadList(
                    projectId: project.id,
                    session: session,
                    members: members,
                    allProfiles: allProfiles,
                    workflow: workflow,
                  ),
                  SessionTab.map => SessionMapView(
                    session: session,
                    members: members,
                    workflow: workflow,
                  ),
                },
              ),
              if (tab == SessionTab.chat && liveTurn != null)
                SessionLiveTurnStrip(turn: liveTurn, members: members),
              if (tab == SessionTab.chat &&
                  session != null &&
                  pendingPermission != null)
                PermissionRequestBanner(
                  request: pendingPermission,
                  busy: running,
                  onRespond: (grant) => ProjectsService.instance.notifier
                      .respondToSessionPermission(
                        project.id,
                        session.id,
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
              if (tab == SessionTab.chat)
                _Composer(project: project, session: session),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 272,
          child: WorkflowProgressPanel(
            project: project,
            session: session,
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
    required this.projectId,
    required this.session,
    required this.members,
    required this.allProfiles,
    required this.workflow,
  });

  final String projectId;
  final Session? session;
  final List<AgentProfile> members;
  final List<AgentProfile> allProfiles;
  final Workflow? workflow;

  @override
  Widget build(BuildContext context) {
    final open = session;
    if (open == null) return _EmptyChannel(projectId: projectId);

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
              projectId: projectId,
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
    required this.projectId,
    required this.message,
    required this.members,
    required this.allProfiles,
    required this.workflow,
  });

  final String projectId;
  final ChatMessage message;
  final List<AgentProfile> members;

  /// Every registered profile, not just this project's members: a message
  /// keeps naming its author even after that agent is removed from the
  /// project. Resolving only against members is what made older messages lose
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
      child: SessionMessageBubble(
        message: message,
        projectId: projectId,
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
  const _Composer({required this.project, required this.session});

  final Project project;
  final Session? session;

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
    if (widget.session?.isRunning ?? false) return;
    ProjectsService.instance.notifier.sendToChannel(widget.project.id, text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final session = widget.session;
    final running = session?.isRunning ?? false;
    final started =
        session?.messages.any((m) => m.role == ChatRole.assistant) ?? false;

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
                  child: ChatComposerField(
                    controller: _controller,
                    onSend: _send,
                    enabled: session != null && !running,
                    hintText: switch (session) {
                      null => 'Creá una sesión para empezar',
                      _ when !started =>
                        'Qué necesitás en esta sesión de #${project.name}',
                      _ => 'Mensaje a #${project.name}',
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: running ? 'Detener' : 'Enviar',
                onPressed: switch ((running, session)) {
                  (true, final open?) =>
                    () => ProjectsService.instance.notifier.stopSession(
                      project.id,
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
            child: Text(switch (session) {
              null => 'Las sesiones se crean con el botón "Nueva sesión".',
              _ when !started =>
                'Arranca el workflow del proyecto en esta sesión.',
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
    required this.project,
    required this.session,
    required this.members,
    required this.workflow,
    required this.tab,
    required this.onTabChanged,
  });

  final Project project;
  final Session? session;
  final List<AgentProfile> members;
  final Workflow? workflow;
  final SessionTab tab;
  final ValueChanged<SessionTab> onTabChanged;

  /// El pull request que abrió esta sesión, si alguno lo nombró en el hilo.
  ///
  /// Se lee de los mensajes y no de un campo propio: el PR lo abre un agente
  /// con `gh` en su turno, y el hilo es donde queda dicho. Guardarlo aparte
  /// sería un segundo lugar donde puede quedar viejo.
  ({int number, String url})? _pullRequest() {
    final open = session;
    if (open == null) return null;
    for (final message in open.messages.reversed) {
      final pr = lastPullRequestIn(message.text);
      if (pr != null) return pr;
    }
    return null;
  }

  /// Per-member cost ledger of the open session, for the subtitle tooltip.
  String _costBreakdown() {
    final open = session;
    if (open == null || open.costUsd <= 0) return '';
    final lines = <String>['Costo de la sesión por miembro:'];
    for (final entry in open.costByProfileId.entries) {
      final member = members.where((m) => m.id == entry.key).firstOrNull;
      lines.add(
        '· ${member?.name ?? 'ex-miembro'}: '
        'US\$${entry.value.toStringAsFixed(2)}',
      );
    }
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final open = session;
    String subtitle;
    if (open == null) {
      subtitle = project.purpose.isEmpty
          ? 'Sin sesión abierta'
          : project.purpose;
    } else {
      subtitle = [
        'Sesión: ${open.title}',
        if (workflow != null) workflow!.name,
        if (open.contextUsageRatio != null)
          'contexto ${(open.contextUsageRatio! * 100).round()}%',
        if (open.costUsd > 0) 'US\$${open.costUsd.toStringAsFixed(2)}',
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
                      project.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                Tooltip(
                  message: _costBreakdown(),
                  child: Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          if (_pullRequest() case final pr?) _PullRequestChip(pr: pr),
          if (open != null)
            IconButton(
              tooltip: 'Agentes de esta sesión',
              icon: const Icon(Icons.person_add_alt_outlined, size: 20),
              onPressed: () => openSessionAgentPicker(
                context,
                projectId: project.id,
                sessionId: open.id,
              ),
            ),
          SegmentedButton<SessionTab>(
            segments: const [
              ButtonSegment(
                value: SessionTab.chat,
                icon: Icon(Icons.forum_outlined, size: 16),
                label: Text('Chat'),
              ),
              ButtonSegment(
                value: SessionTab.map,
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

/// El PR de la sesión, en el encabezado. Está también en el hilo, pero a los
/// cuarenta mensajes hay que ir a buscarlo: acá se llega de un click desde
/// cualquier punto de la conversación.
class _PullRequestChip extends StatelessWidget {
  const _PullRequestChip({required this.pr});

  final ({int number, String url}) pr;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: 'Abrir ${pr.url}',
        child: TextButton.icon(
          onPressed: () => openExternalUrl(pr.url),
          icon: Icon(Icons.call_merge, size: 15, color: scheme.tertiary),
          label: Text(
            'PR #${pr.number}',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: scheme.tertiary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The project's members as overlapping colour chips — who is in the room,
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
  const _EmptyChannel({required this.projectId});

  final String projectId;

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
              'Ninguna sesión abierta',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Cada sesión es un entorno aparte: su propio hilo y su propio '
              'contexto, con toda la configuración de este proyecto.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  ProjectsService.instance.notifier.createSession(projectId),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nueva sesión'),
            ),
          ],
        ),
      ),
    );
  }
}

/// An imported project lands without a working directory (paths never
/// travel in the catalog) — nothing can run until the user picks one here.
class _MissingFolderBanner extends StatelessWidget {
  const _MissingFolderBanner({required this.projectId});

  final String projectId;

  Future<void> _pickFolder() async {
    final path = await getDirectoryPath(confirmButtonText: 'Usar esta carpeta');
    if (path == null) return;
    ProjectsService.instance.notifier.setProjectWorkingDirectory(
      projectId,
      path,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.folder_off_outlined,
            size: 18,
            color: scheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Este proyecto no tiene carpeta de trabajo (vino de un '
              'import). Elegila para poder correr sesiones.',
              style: TextStyle(color: scheme.onErrorContainer, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _pickFolder,
            child: const Text('Elegir carpeta'),
          ),
        ],
      ),
    );
  }
}
